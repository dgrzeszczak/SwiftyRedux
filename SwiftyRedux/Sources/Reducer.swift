//
//  Reducer.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 29/01/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

public protocol Reducer {
    associatedtype Action: StoreAction
    associatedtype State

    static func reduce(state: State, with action: Action) -> State
}

extension Reducer {
    public static var any: AnyReducer<State> { return AnyReducer(reducer: self) }
}

public struct AnyReducer<State> {


    private var reducer: (_ state: State, _ action: StoreAction) -> State

    init<Action, R: Reducer>(reducer: R.Type) where R.Action == Action, R.State == State {
        self.reducer = { state, action in
            guard type(of: action) == Action.self, let action = action as? Action else { return state }
            return reducer.reduce(state: state, with: action)
        }
    }

    public init(with reducers: [AnyReducer<State>]) {
        self.reducer = { state, action in
            return reducers.reduce(state) { state, reducer in
                return reducer.reduce(state: state, with: action)
            }
        }
    }

    public init(reducer: @escaping (_ state: State, _ action: StoreAction) -> State) {
        self.reducer = reducer
    }

    public func reduce(state: State, with action: StoreAction) -> State {
        return self.reducer(state, action)
    }
}

public struct EmptyReducer<Action: StoreAction, State: StoreState>: Reducer {

    public static func reduce(state: State, with action: Action) -> State {
        return state
    }
}
