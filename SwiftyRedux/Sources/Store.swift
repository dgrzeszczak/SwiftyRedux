//
//  Store.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 29/01/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

import Foundation

public typealias StoreState = Any

public protocol StoreActionDispatcher {
    func dispatch(action: StoreAction)
}

public protocol StoreStateSubject {
    func add<Subscriber>(subscriber: Subscriber) where Subscriber: StoreSubscriber
    func remove<Subscriber>(subscriber: Subscriber) where Subscriber: StoreSubscriber
}

public class Store<State: StoreState>: StoreActionDispatcher, StoreStateSubject {

    private(set) public var state: State
    private var middleware: [AnyMiddleware]
    private let reducer: AnyReducer<State>

    public init(with state: State, reducer: AnyReducer<State>, middleware: [AnyMiddleware] = []) {
        self.state = state
        self.middleware = middleware
        self.reducer = reducer
    }

    public func dispatch(action: StoreAction) {

        let dispatcher = MiddlewareDispatcher<State>(store: self,
                                                     completion: nil,
                                                     middleware: middleware,
                                                     reduce: { [weak self] in
                                                        self?.reduce(with: action)
                                                     })

        AnyDispatcher<State>(dispatcher: dispatcher, action: action).next()
    }

    private func reduce(with action: StoreAction) {
        let oldState = state
        activeSubscribers.forEach { $0.willChange(state: oldState) }
        state = reducer.reduce(state: oldState, with: action)
        activeSubscribers.forEach { $0.didChange(state: state, oldState: oldState) }
        activeSubscribers.forEach { $0.didSet(state: state) }
    }

    private var subscribers = [AnyWeakStoreSubscriber]()
    private var activeSubscribers: [AnyWeakStoreSubscriber] {
        subscribers = subscribers.filter { $0.subscriber != nil }
        return subscribers
    }

    public func add<Subscriber>(subscriber: Subscriber) where Subscriber: StoreSubscriber {
        guard !activeSubscribers.contains(where: { $0.subscriber === subscriber }) else { return }
        let anySubscriber = AnyWeakStoreSubscriber(subscriber: subscriber)
        subscribers.append(anySubscriber)
        anySubscriber.didSet(state: state)
    }

    public func remove<Subscriber>(subscriber: Subscriber) where Subscriber: StoreSubscriber {
        guard let index = activeSubscribers.firstIndex(where: { $0.subscriber === subscriber }) else { return }
        subscribers.remove(at: index)
    }
}
