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

class AnyWeakStoreSubscriber: StoreSubscriber {

    private let _willChange: ((_ state: StoreState) -> Void)
    private let _didChange: ((_ state: StoreState, _ oldState: StoreState) -> Void)

    private let _didSet: ((_ state: StoreState) -> Void)

    private(set) weak var subscriber: AnyObject?

    init<Subscriber>(subscriber: Subscriber) where Subscriber: StoreSubscriber {
        self.subscriber = subscriber

        _willChange = { [weak subscriber] state in
            guard let state = state as? Subscriber.State else { return }
            subscriber?.willChange(state: state)
        }

        _didChange = { [weak subscriber] state, oldState in
            guard let state = state as? Subscriber.State, let oldState = oldState as? Subscriber.State else { return }
            subscriber?.didChange(state: state, oldState: oldState)
        }

        _didSet = { [weak subscriber] state in
            guard let state = state as? Subscriber.State else { return }
            subscriber?.didSet(state: state)
        }
    }

    func willChange(state: StoreState) {
        _willChange(state)
    }

    func didChange(state: StoreState, oldState: StoreState) {
        _didChange(state, oldState)
    }

    func didSet(state: Any) {
        _didSet(state)
    }
}
