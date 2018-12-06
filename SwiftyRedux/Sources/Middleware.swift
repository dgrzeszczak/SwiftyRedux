//
//  Middleware.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 22/09/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

public protocol AnyMiddleware {
    func applyAnyMiddleware<Action: StoreAction, State: StoreState>(with action: Action, dispatcher: Dispatcher<Action, State>, state: State)
}

public protocol Middleware: AnyMiddleware {
    associatedtype Action: StoreAction
    associatedtype State: StoreState
    func applyMiddleware(with action: Action, dispatcher: Dispatcher<Action, State>, state: State)
}

extension AnyMiddleware where Self: Middleware {
    public func applyAnyMiddleware<Action: StoreAction, State: StoreState>(with action: Action,
                                                                           dispatcher: Dispatcher<Action, State>, state: State) {
        guard Action.self == Self.Action.self,
            let state = state as? Self.State,
            let action = action as? Self.Action,
            let dis = dispatcher as? Dispatcher<Self.Action, Self.State>
        else {
            dispatcher.next()
            return
        }

        applyMiddleware(with: action, dispatcher: dis, state: state)
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
        first.applyAnyMiddleware(with: action, dispatcher: dispatch, state: store.state)
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
