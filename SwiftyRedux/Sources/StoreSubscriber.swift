//
//  StoreSubscriber.swift
//  ReMVVM
//
//  Created by Dariusz Grzeszczak on 18/09/2018.
//  Copyright © 2018 Dariusz Grzeszczak. All rights reserved.
//

import Foundation

public protocol StoreSubscriber: class {
    associatedtype State: StoreState

    func willChange(state: State)
    func didChange(state: State, oldState: State)

    func didSet(state: State) // similar to didChange but also is called with initial value
}

public extension StoreSubscriber {
    func willChange(state: State) { }
    func didChange(state: State, oldState: State) { }

    func didSet(state: State) { }
}

class AnyWeakStoreSubscriber<State: StoreState>: StoreSubscriber {

    private let _willChange: ((_ state: State) -> Void)
    private let _didChange: ((_ state: State, _ oldState: State) -> Void)

    private let _didSet: ((_ state: State) -> Void)

    private(set) weak var subscriber: AnyObject?

    init<Subscriber>(subscriber: Subscriber) where Subscriber: StoreSubscriber, Subscriber.State == State {
        self.subscriber = subscriber

        _willChange = { [weak subscriber] state in
            subscriber?.willChange(state: state)
        }

        _didChange = { [weak subscriber] state, oldState in
            subscriber?.didChange(state: state, oldState: oldState)
        }

        _didSet = { [weak subscriber] state in
            subscriber?.didSet(state: state)
        }
    }

    func willChange(state: State) {
        _willChange(state)
    }

    func didChange(state: State, oldState: State) {
        _didChange(state, oldState)
    }

    func didSet(state: State) {
        _didSet(state)
    }
}
