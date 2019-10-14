//
//  Middleware.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 22/09/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

public protocol AnyMiddleware {

    func onNext<State: StoreState>(for state: State, action: StoreAction, interceptor: Interceptor<StoreAction, State>, dispatcher: StoreActionDispatcher)
}

public protocol Middleware: AnyMiddleware {
    associatedtype Action: StoreAction
    associatedtype State: StoreState

    func onNext(for state: State, action: Action, interceptor: Interceptor<Action, State>, dispatcher: StoreActionDispatcher)
}

extension AnyMiddleware where Self: Middleware {
    public func onNext<State: StoreState>(for state: State, action: StoreAction, interceptor: Interceptor<StoreAction, State>, dispatcher: StoreActionDispatcher) {
        guard   let action = action as? Self.Action,
                let state = state as? Self.State,
                let middleware = interceptor as? Interceptor<StoreAction, Self.State>
        else {
            interceptor.next()
            return
        }

        let middle = Interceptor<Self.Action, Self.State> { act, completion in
            middleware.next(action: act ?? action, completion: completion)
        }
        onNext(for: state, action: action, interceptor: middle, dispatcher: dispatcher)
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

        guard !middleware.isEmpty else { // reduce if no more interceptor
            reduce()
            compl?(store.state)
            return
        }

        var newWiddleware = middleware
        let first = newWiddleware.removeFirst()
        let middlewareDispatcher = MiddlewareDispatcher(store: store, completion: compl, middleware: newWiddleware, reduce: reduce)

        let interceptor =  Interceptor<StoreAction, State> { act, completion in
            middlewareDispatcher.next(action: act ?? action, completion: completion)
        }
        first.onNext(for: store.state, action: action, interceptor: interceptor, dispatcher: store)
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

public typealias MiddlewareInterceptorFunction<Action, State> = (Action?, ((State) -> Void)?) -> Void where State: StoreState
public struct Interceptor<Action, State: StoreState> {

    private let function: MiddlewareInterceptorFunction<Action, State>
    public init(function: @escaping MiddlewareInterceptorFunction<Action, State>) {
        self.function = function
    }

    public func next(action: Action? = nil, completion: ((State) -> Void)? = nil) {
        function(action, completion)
    }
}
