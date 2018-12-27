//
//  Reducer.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 29/01/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

public protocol Reducer {
    associatedtype Action: StoreAction
    associatedtype State: StoreState

    static func reduce(state: State, with action: Action) -> State
}

public struct EmptyReducer<Action: StoreAction, State: StoreState>: Reducer {

    public static func reduce(state: State, with action: Action) -> State {
        return state
    }
}
