//
//  Middleware.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 22/09/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

// TODO ??
//protocol Middlewares {
//    associatedtype Action
//    associatedtype State
//
//    func next()
//    func next(completion: @escaping (State) -> Void)
//
//    func next(action: StoreAction)
//    func next(action: StoreAction, completion: @escaping (State) -> Void)
//}

public protocol AnyMiddleware {
    // TODO combine State + dispatcher = Store (find name) - change name for subjects ?

    func next<State: StoreState>(for state: State, action: StoreAction, middlewares: AnyMiddlewares<State>, dispatcher: StoreActionDispatcher)
}

public protocol Middleware: AnyMiddleware {
    associatedtype Action: StoreAction
    associatedtype State: StoreState

    func next(for state: State, action: Action, middlewares: Middlewares<Action, State>, dispatcher: StoreActionDispatcher)
}

extension AnyMiddleware where Self: Middleware {
    public func next<State: StoreState>(for state: State, action: StoreAction, middlewares: AnyMiddlewares<State>, dispatcher: StoreActionDispatcher) {
        guard   let action = action as? Self.Action,
                let state = state as? Self.State,
                let middlewareDispatcher = middlewares.dispatcher as? MiddlewareDispatcher<Self.State>
        else {
            middlewares.next()
            return
        }

        let middlewares = Middlewares<Self.Action, Self.State>(dispatcher: middlewareDispatcher, action: action)
        next(for: state, action: action, middlewares: middlewares, dispatcher: dispatcher)
    }
}

struct MiddlewareDispatcher<State: StoreState>: StoreActionDispatcher {
    weak var store: Store<State>?
    let completion: ((State) -> Void)?
    let middleware: [AnyMiddleware]
    let reduce: () -> Void

    func dispatch(action: StoreAction) {
        store?.dispatch(action: action)
    }

    func next(action: StoreAction, completion: ((State) -> Void)? = nil) {

        guard let store = store else { return } // store dealocated no need to do

        let compl = compose(completion1: self.completion, completion2: completion)

        guard !middleware.isEmpty else { // reduce if no more middlewares
            reduce()
            compl?(store.state)
            return
        }

        var newWiddleware = middleware
        let first = newWiddleware.removeFirst()
        let middlewareDispatcher = MiddlewareDispatcher(store: store, completion: compl, middleware: newWiddleware, reduce: reduce)

        let middlewares = AnyMiddlewares(dispatcher: middlewareDispatcher, action: action)
        first.next(for: store.state, action: action, middlewares: middlewares, dispatcher: store)
    }

    private func compose(completion1: ((State) -> Void)?, completion2: ((State) -> Void)?) -> ((State) -> Void)? {
        guard let completion1 = completion1 else { return completion2 }
        guard let completion2 = completion2 else { return completion1 }
        return { state in
            completion2(state)
            completion1(state)
        }
    }
}

public struct AnyMiddlewares<State: StoreState> {

    let dispatcher: MiddlewareDispatcher<State>
    let action: StoreAction

    public func next(completion: ((State) -> Void)? = nil) {
        next(action: action, completion: completion)
    }

    public func next(action: StoreAction, completion: ((State) -> Void)? = nil) {
        dispatcher.next(action: action, completion: completion)
    }
}

public struct Middlewares<Action: StoreAction, State: StoreState> {

    let dispatcher: MiddlewareDispatcher<State>
    let action: Action

    public func next(completion: ((State) -> Void)? = nil) {
        next(action: action, completion: completion)
    }

    public func next(action: Action, completion: ((State) -> Void)? = nil) {
        dispatcher.next(action: action, completion: completion)
    }
}
