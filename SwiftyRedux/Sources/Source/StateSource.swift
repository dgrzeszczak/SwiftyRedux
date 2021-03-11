//
//  StateSource.swift
//  SwiftyRedux
//
//  Created by Dariusz Grzeszczak on 10/12/2019.
//  Copyright © 2019 Dariusz Grzeszczak. All rights reserved.
//

import Foundation

@available(*, deprecated, renamed: "AnyStateSource")
public typealias AnyStateSubject = AnyStateSource

@available(*, deprecated, renamed: "Source")
public typealias Subject = Source

@available(*, deprecated, renamed: "StateSource")
public typealias StateSubject = StateSource

@available(*, deprecated, renamed: "MockStateSource")
public typealias MockStateSubject = MockStateSource

#if swift(>=5.1) && canImport(Combine)
import Combine

public typealias StateSourced<State> = AnyStateSource<State>.Wrapper
/// Type erased StateSource
public class AnyStateSource<State>: StateSource {

    /// Current state value
    @Wrapper public var state: State? //{ _state() }

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

    @propertyWrapper
    public struct Wrapper {

        private let state: () -> State?
        private let source: Source

        public var wrappedValue: State? { state() }

        @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
        public var projectedValue: Publisher { Publisher(source: source) }

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
    }
}
#else
/// Type erased StateSource
public class AnyStateSource<State>: StateSource {

    private let _state: () -> State?
    private let source: Source

    /// Current state value
    public var state: State? { _state() }

    /// Adds state observer
    /// - Parameter observer: observer to be notified on state changes
    public func add<Observer>(observer: Observer) where Observer : StateObserver {
        source.add(observer: observer)
    }

    /// Removes state observer
    /// - Parameter observer: observer to remove
    public func remove<Observer>(observer: Observer) where Observer : StateObserver {
        source.remove(observer: observer)
    }

    /// Initializes erased type value
    /// - Parameter source: source to erase type
    public init<S: StateSource>(source: S) where S.State == State {
        self.source = source
        _state = { source.state }
    }
}
#endif

extension AnyStateSource {

    public static func mock(_ state: State) -> AnyStateSource<State> { MockStateSource(state: state).any }
}

/// Source with current state
public protocol StateSource: StateAssociated, Source {
    /// Current state value
    var state: State? { get }
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

