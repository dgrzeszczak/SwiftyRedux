//
//  StateSubscriber.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 18/09/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

import Foundation

@available(*, deprecated, renamed: "StateSubscriber")
public typealias StoreSubscriber = StateSubscriber

public protocol StateAssociated {
    associatedtype State
}

public protocol StateSubscriber: class, StateAssociated {

    associatedtype State
    func willChange(state: State)
    func didChange(state: State, oldState: State?)
}

public extension StateSubscriber {
    func willChange(state: State) { }
    func didChange(state: State, oldState: State?) { }
}

public protocol Subject {
    func add<Subscriber>(subscriber: Subscriber) where Subscriber: StateSubscriber
    func remove<Subscriber>(subscriber: Subscriber) where Subscriber: StateSubscriber
}

public protocol StateSubject: StateAssociated, Subject {
    var state: State? { get }
}

public final class MockStateSubject<State>: StateSubject {

    public private(set) var state: State? {
        willSet {
            subject.notifyStateWillChange(oldState: state!)
        }

        didSet {
            subject.notifyStateDidChange(state: state!, oldState: oldValue!)
        }
    }

    private let subject = StoreSubject<State>()

    public init(state: State) {

        self.state = state
    }

    public func updateState(state: State) {
        self.state = state
    }

    public func add<Subscriber>(subscriber: Subscriber) where Subscriber: StateSubscriber {
        if let subscriber = subject.add(subscriber: subscriber) { // new subcriber added with success
            subscriber.didChange(state: state!, oldState: nil)
        }
    }

    public func remove<Subscriber>(subscriber: Subscriber) where Subscriber: StateSubscriber {
        subject.remove(subscriber: subscriber)
    }
}

extension StateSubject {
    public var any: AnyStateSubject<State> { AnyStateSubject(subject: self) }
}

public struct AnyStateSubject<State>: StateSubject {

    private let _state: () -> State?
    private let subject: Subject

    public var state: State? { _state() }

    public func add<Subscriber>(subscriber: Subscriber) where Subscriber : StateSubscriber {
        subject.add(subscriber: subscriber)
    }

    public func remove<Subscriber>(subscriber: Subscriber) where Subscriber : StateSubscriber {
        subject.remove(subscriber: subscriber)
    }

    public init<S: StateSubject>(subject: S) where S.State == State {
        self.subject = subject
        _state = { subject.state }
    }
}

public protocol AnyStateTypeSubject: Subject {
    func anyState<State>() -> State?
}

class AnyWeakStoreSubscriber<State>: StateSubscriber {

    private let _willChange: ((_ state: Any) -> Void)
    private let _didChange: ((_ state: Any, _ oldState: Any?) -> Void)

    private(set) weak var subscriber: AnyObject?

    init<Subscriber>(subscriber: Subscriber) where Subscriber: StateSubscriber {

        self.subscriber = subscriber

        _willChange = { [weak subscriber] state in
            guard   let subscriber = subscriber,
                    let state = state as? Subscriber.State
            else { return }

            subscriber.willChange(state: state )
        }

        _didChange = { [weak subscriber] state, oldState in
            guard   let subscriber = subscriber,
                    let state = state as? Subscriber.State
            else { return }

            let oldState = oldState as? Subscriber.State
            subscriber.didChange(state: state, oldState: oldState)
        }
    }

    init?<Subscriber>(subscriber: Subscriber, mapper: StateMapper<State>) where Subscriber: StateSubscriber {
        guard mapper.matches(state: Subscriber.State.self) else { return nil }

        self.subscriber = subscriber

        _willChange = { [weak subscriber] state in
            guard   let subscriber = subscriber,
                    let state: Subscriber.State = mapper.map(state: state as! State)
            else { return }

            subscriber.willChange(state: state )
        }

        _didChange = { [weak subscriber] state, oldState in
            guard   let subscriber = subscriber,
                    let state: Subscriber.State = mapper.map(state: state as! State)
            else { return }

            guard oldState != nil else {
                subscriber.didChange(state: state, oldState: nil)
                return
            }

            guard let oldState: Subscriber.State = mapper.map(state: oldState as! State) else {
                return
            }

            subscriber.didChange(state: state, oldState: oldState)
        }
    }

    func willChange(state: State) {
        _willChange(state)
    }

    func didChange(state: State, oldState: State?) {
        _didChange(state, oldState)
    }
}

//public struct StoreStateMapper<State: StoreState, NewState> {
//
//    public let closure: (State) -> NewState
//    public init(map: @escaping (State) -> NewState) {
//        closure = map
//    }
//    public func map(state: State) -> NewState {
//        return closure(state)
//    }
//}


@available(*, deprecated, renamed: "StateMapper")
public typealias StoreStateMapper = StateMapper

public struct StateMapper<State> {

    let newStateType: Any.Type
    private let _map: (State) -> Any
    public init<NewState>(map: @escaping (State) -> NewState) {
        newStateType = NewState.self
        _map = { map($0) }
    }

    func matches<State>(state: State.Type) -> Bool {
        return newStateType == state
    }

    func map<NewState>(state: State) -> NewState? {
        guard newStateType == NewState.self else { return nil }
        return _map(state) as? NewState
    }
}
