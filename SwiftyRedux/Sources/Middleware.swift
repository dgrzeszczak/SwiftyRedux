//
//  Middleware.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 22/09/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

public protocol AnyMiddleware {
    func applyAnyMiddleware<State: StoreState, Action: StoreAction>(for state: State,
                                                                    action: Action,
                                                                    dispatcher: Dispatcher<Action, State>)
}

public protocol Middleware: AnyMiddleware {
    associatedtype Action: StoreAction
    associatedtype State: StoreState
    func applyMiddleware(for state: State, action: Action, dispatcher: Dispatcher<Action, State>)
}

extension AnyMiddleware where Self: Middleware {
    public func applyAnyMiddleware<State: StoreState, Action: StoreAction>(for state: State,
                                                                           action: Action,
                                                                           dispatcher: Dispatcher<Action, State>) {
        guard let state = state as? Self.State,
            let action = action as? Self.Action,
            let dis = dispatcher as? Dispatcher<Self.Action, Self.State>
        else {
            dispatcher.next()
            return
        }

        applyMiddleware(for: state, action: action, dispatcher: dis)
    }
}

//protocol StoreActionDispatcher: class {
//    func dispatch<Action: StoreAction>(action: Action)
//}
//
//extension Store: StoreActionDispatcher { }

public struct Dispatcher<Action: StoreAction, State: StoreState> {

    weak var store: Store<State>?
    let completion: ((State) -> Void)?
    let middleware: [AnyMiddleware]
    let reduce: () -> Void

    let action: Action

    public func dispatch<Action: StoreAction>(action: Action) {
        store?.dispatch(action: action)
    }

    public func next(completion: ((State) -> Void)? = nil) {
        next(action: action, completion: completion)
    }

    public func next(action: Action, completion: ((State) -> Void)? = nil) {

        guard let store = store else { return } // store dealocated no need to do

        let compl = compose(completion1: self.completion, completion2: completion)

        guard !middleware.isEmpty else { // reduce if no more middlewares
            reduce()
            compl?(store.state)
            return
        }

        var newWiddleware = middleware
        let first = newWiddleware.removeFirst()
        let dispatch = Dispatcher(store: store,
                                completion: compl,
                                middleware: newWiddleware,
                                reduce: reduce,
                                action: action)
        first.applyAnyMiddleware(for: store.state, action: action, dispatcher: dispatch)
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
