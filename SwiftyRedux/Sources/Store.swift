//
//  Store.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 29/01/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

import Foundation

public protocol StoreActionDispatcher {
    func dispatch(action: StoreAction)
}

public class Store<State: StoreState>: StoreActionDispatcher, AnyStateSubject {

    private(set) public var state: State
    private var middleware: [AnyMiddleware]
    private let reducer: AnyReducer<State>
    private let subject: Subject<State>

    public init(with state: State, reducer: AnyReducer<State>, middleware: [AnyMiddleware] = [], stateMappers: [StoreStateMapper<State>] = []) {
        self.state = state
        self.middleware = middleware
        self.reducer = reducer
        subject = Subject(stateMappers: stateMappers)
    }

    public func dispatch(action: StoreAction) {

        let dispatcher = MiddlewareDispatcher<State>(store: self,
                                                     completion: nil,
                                                     middleware: middleware,
                                                     reduce: { [weak self] in
                                                        self?.reduce(with: action)
                                                     })

        MiddlewareInterceptor<StoreAction, State> { act, completion in
            dispatcher.next(action: act ?? action, completion: completion)
        }.next()
    }

    private func reduce(with action: StoreAction) {
        let oldState = state
        subject.notifyStateWillChange(oldState: oldState)
        state = reducer.reduce(state: oldState, with: action)
        subject.notifyStateDidChange(state: state, oldState: oldState)
    }

    public func add<Subscriber>(subscriber: Subscriber) where Subscriber: StateSubscriber {
        if let subscriber = subject.add(subscriber: subscriber) { // new subcriber added with success
            subscriber.didChange(state: state, oldState: nil)
        }
    }

    public func remove<Subscriber>(subscriber: Subscriber) where Subscriber: StateSubscriber {
        subject.remove(subscriber: subscriber)
    }

    public func anyState<State>() -> State? {
        return subject.anyState(state: state)
    }
}

fileprivate final class Subject<State: StoreState> {

    private var subscribers = [AnyWeakStoreSubscriber<State>]()
    private var activeSubscribers: [AnyWeakStoreSubscriber<State>] {
        subscribers = subscribers.filter { $0.subscriber != nil }
        return subscribers
    }

    var mappers: [StoreStateMapper<State>]
    init(stateMappers: [StoreStateMapper<State>] = []) {
        stateMappers.map { $0.newStateType }.forEach { newStateType in
            let count = stateMappers.filter { $0.newStateType == newStateType }.count
            guard count == 1 else {
                fatalError("More state mappers for the same type: \(newStateType)")
            }
        }
        mappers = stateMappers
    }

    func anyState<AnyState>(state: State) -> AnyState? {
        if AnyState.self == State.self { return (state as! AnyState) }
        let anyState: AnyState? = mappers.first { $0.matches(state: AnyState.self) }?.map(state: state)
        return anyState ?? state as? AnyState
    }

    //return nil if subscriber already added
    func add<Subscriber>(subscriber: Subscriber) -> AnyWeakStoreSubscriber<State>? where Subscriber: StateSubscriber {
        guard !activeSubscribers.contains(where: { $0.subscriber === subscriber }) else { return nil }

        //TODO optimize it
        let anySubscriber = mappers
            .first { $0.matches(state: Subscriber.State.self) }
            .flatMap { AnyWeakStoreSubscriber<State>(subscriber: subscriber, mapper: $0) }
            ?? AnyWeakStoreSubscriber<State>(subscriber: subscriber)

        subscribers.append(anySubscriber)
        return anySubscriber
    }

    func remove<Subscriber>(subscriber: Subscriber) where Subscriber : StateSubscriber {
        guard let index = activeSubscribers.firstIndex(where: { $0.subscriber === subscriber }) else { return }
        subscribers.remove(at: index)
    }

    func notifyStateWillChange(oldState: State) {
        activeSubscribers.forEach { $0.willChange(state: oldState) }
    }

    func notifyStateDidChange(state: State, oldState: State) {
        activeSubscribers.forEach { $0.didChange(state: state, oldState: oldState) }
    }
}
