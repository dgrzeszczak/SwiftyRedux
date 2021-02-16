//
//  StateSubject.swift
//  SwiftyRedux
//
//  Created by Dariusz Grzeszczak on 10/12/2019.
//  Copyright © 2019 Dariusz Grzeszczak. All rights reserved.
//

import Foundation
#if swift(>=5.1)
#if canImport(Combine)
import Combine
#endif

@propertyWrapper
public struct StatePublished<State> {

    private let state: () -> State?
    private let subject: Subject

    public var wrappedValue: State? { state() }

    #if canImport(Combine)
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public var projectedValue: Publisher { Publisher(subject: subject) }
    #endif

    func add<Observer>(observer: Observer) where Observer : StateObserver {
        subject.add(observer: observer)
    }

    func remove<Observer>(observer: Observer) where Observer : StateObserver {
        subject.remove(observer: observer)
    }

    public init(from subject: AnyStateSubject<State>) {
        self.subject = subject
        state = { subject.state }
    }

    init<S: StateSubject>(from subject: S) where S.State == State {
        self.subject = subject
        state = { subject.state }
    }

    #if canImport(Combine)
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public struct Publisher: Combine.Publisher {

        public typealias Output = State

        public typealias Failure = Never

        let subject: Subject

        public func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {

            let subscription = Subscription(target: subscriber)
            subscriber.receive(subscription: subscription)
            subject.add(observer: subscription)
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

/// Type erased StateSubject
public class AnyStateSubject<State>: StateSubject {

    /// Current state value
    @StatePublished public var state: State? //{ _state() }

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
    /// - Parameter subject: subject to erase type
    public init<S: StateSubject>(subject: S) where S.State == State {
        _state = .init(from: subject)
    }
}
#else
/// Type erased StateSubject
public class AnyStateSubject<State>: StateSubject {

    private let _state: () -> State?
    private let subject: Subject

    /// Current state value
    public var state: State? { _state() }

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
    public init<S: StateSubject>(subject: S) where S.State == State {
        self.subject = subject
        _state = { subject.state }
    }
}
#endif

extension AnyStateSubject {

    public static var store: AnyStateSubject<State> { StoreStateSubject<State>().any }
    public static func mock(_ state: State) -> AnyStateSubject<State> { MockStateSubject(state: state).any }

}

/// Subject with current state
public protocol StateSubject: StateAssociated, Subject {
    /// Current state value
    var state: State? { get }
}

extension StateSubject {
    /// type erased value
    public var any: AnyStateSubject<State> {
        guard let any = self as? AnyStateSubject<State> else {
            return AnyStateSubject(subject: self)
        }

        return any
    }
}

