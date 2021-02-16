//
//  File.swift
//  
//
//  Created by Dariusz Grzeszczak on 14/01/2021.
//
import Foundation
#if swift(>=5.1)
#if canImport(Combine)
import Combine
#endif

@propertyWrapper
public struct StateSourcePublished<State> {

    private let state: () -> State
    private let source: Source

    public var wrappedValue: State { state() }

    #if canImport(Combine)
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public var projectedValue: Publisher { Publisher(source: source) }
    #endif

    func add<Observer>(observer: Observer) where Observer : StateObserver {
        source.add(observer: observer)
    }

    func remove<Observer>(observer: Observer) where Observer : StateObserver {
        source.remove(observer: observer)
    }

    public init(from source: AnyStateSource<State>) {
        self.source = source
        state = { source.state }
    }

    init<S: StateSource>(from source: S) where S.State == State {
        self.source = source
        state = { source.state }
    }

    #if canImport(Combine)
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public struct Publisher: Combine.Publisher {

        public typealias Output = State

        public typealias Failure = Never

        let source: Source

        public func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {

            let subscription = Subscription(target: subscriber)
            subscriber.receive(subscription: subscription)
            source.add(observer: subscription)
        }


        class Subscription<Target: Subscriber>: Combine.Subscription, StateObserver where Target.Input == State {

            var target: Target?

            init(target:Target) {
                self.target = target
            }

            func request(_ demand: Subscribers.Demand) {}

            func cancel() {
                target = nil
            }

            func didChange(state: State, oldState: State?) {
                _ = target?.receive(state)
            }

        }
    }
    #endif
}


/// Type erased StateSource
public struct AnyStateSource<State>: StateSource {

    /// Current state value
    @StateSourcePublished public var state: State //{ _state() }

    /// Adds state observer
    /// - Parameter observer: observer to be notified on state changes
    public func add<Observer>(observer: Observer) where Observer : StateObserver {
        _state.add(observer: observer)
    }

    /// Removes state observer
    /// - Parameter observer: observer to remove
    public func remove<Observer>(observer: Observer) where Observer : StateObserver {
        _state.remove(observer: observer)
    }

    /// Initializes erased type value
    /// - Parameter source: source to erase type
    public init<S: StateSource>(source: S) where S.State == State {
        _state = .init(from: source)
    }
}
#else
/// Type erased StateSubject
public struct AnyStateSource<State>: StateSource {

    private let _state: () -> State?
    private let source: Source

    /// Current state value
    public var state: State { _state() }

    /// Adds state observer
    /// - Parameter observer: observer to be notified on state changes
    public func add<Observer>(observer: Observer) where Observer : StateObserver {
        subject.add(observer: observer)
    }

    /// Removes state observer
    /// - Parameter observer: observer to remove
    public func remove<Observer>(observer: Observer) where Observer : StateObserver {
        subject.remove(observer: observer)
    }

    /// Initializes erased type value
    /// - Parameter subject: subject to erase type
    public init<S: StateSource>(source: S) where S.State == State {
        self.source = source
        _state = { subject.state }
    }
}
#endif


/// Describes a source that can be used to observe state changes
public protocol Source {

    /// Adds state observer
    /// - Parameter observer: observer to be notified on state changes
    func add<Observer>(observer: Observer) where Observer: StateObserver

    /// Removes state observer
    /// - Parameter observer: observer to remove
    func remove<Observer>(observer: Observer) where Observer: StateObserver
}

/// Source with current state
public protocol StateSource: StateAssociated, Source {
    /// Current state value
    var state: State { get }
}

extension AnyStateSource {
    public static var store: AnyStateSource<State>? { StoreStateSource<State>()?.any }
    public static func mock(_ state: State) -> AnyStateSource<State> { MockStateSource(state: state).any }
}

extension StateSource {
    /// type erased value
    public var any: AnyStateSource<State> {
        guard let any = self as? AnyStateSource<State> else {
            return AnyStateSource(source: self)
        }

        return any
    }
}

//store source

struct StoreStateSource<State>: StateSource {

    let store: Dispatcher & Subject & AnyStateProvider = ReMVVM<Any>.store
    var state: State { store.anyState()! }

    init?() {
        guard let _: State = store.anyState() else { return nil }
    }

    func add<Observer>(observer: Observer) where Observer : StateObserver {
        store.add(observer: observer)
    }

    func remove<Observer>(observer: Observer) where Observer : StateObserver {
        store.remove(observer: observer)
    }
}


//mock
public final class MockStateSource<State>: StateSource {

    /// Current state value
    public private(set) var state: State {
        willSet {
            subject.notifyStateWillChange(oldState: state)
        }

        didSet {
            subject.notifyStateDidChange(state: state, oldState: oldValue)
        }
    }

    private let subject = StoreSubject<State>()

    /// Initializes subject with the state
    /// - Parameter state: initial state
    public init(state: State) {

        self.state = state
    }

    /// Updates the state in the subject
    /// - Parameter state: new state
    public func updateState(state: State) {
        self.state = state
    }

    /// Adds state observer
    /// - Parameter observer: observer to be notified on state changes
    public func add<Observer>(observer: Observer) where Observer: StateObserver {
        if let observer = subject.add(observer: observer) { // new subcriber added with success
            observer.didChange(state: state, oldState: nil)
        }
    }

    /// Removes state observer
    /// - Parameter observer: observer to remove
    public func remove<Observer>(observer: Observer) where Observer: StateObserver {
        subject.remove(observer: observer)
    }
}

//factory


public protocol FailingInitializable {
    init?()
    static var failing: Bool { get }
}


public protocol StateSourceInitializable: StateAssociated, FailingInitializable {
    associatedtype State = State

    init(with source: AnyStateSource<State>)
}

extension StateSourceInitializable {

    public init?() {
        guard let source = AnyStateSource<State>.store else { return nil }
        self.init(with: source)
    }

    public static var failing: Bool {
        StoreStateSource<State>() == nil
    }
}

public struct StateSourceInitializableViewModelFactory: ViewModelFactory {

    /// Initializes factory
    public init() { }

    /// Returns true if is able to create view model of specified type
    /// - Parameter type: view model's type to be created
    public func creates<VM>(type: VM.Type) -> Bool {
        guard let type = type as? FailingInitializable.Type else { return false }
        return !type.failing
    }

    /// Creates view model of specified type or returns nil if is not able
    /// - Parameter key: optional identifier
    public func create<VM>(key: String?) -> VM? {
        guard let type = VM.self as? FailingInitializable.Type else { return nil }
        return type.init() as? VM
    }
}
