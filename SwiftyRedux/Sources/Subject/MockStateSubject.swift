//
//  MockStateSubject.swift
//  SwiftyRedux
//
//  Created by Dariusz Grzeszczak on 10/12/2019.
//  Copyright © 2019 Dariusz Grzeszczak. All rights reserved.
//

import Foundation

/**
 Helper StateSubject that may be used for testing objects that are based on state subjects

 #Example
     func testViewModel() {

         var state = ApplicationState()
         let mock = MockStateSubject(state: state)
         let viewModel = HomeViewModel(with: mock.any)

         XCTAssert(viewModel.isLogged == false)

         state = ApplicationState(user: User(name: "James Bond"))
         mock.updateState(state: state)

         XCTAssert(viewModel.isLogged == true)
     }
 */
public final class MockStateSubject<State>: StateSubject {

    /// Current state value
    public private(set) var state: State? {
        willSet {
            subject.notifyStateWillChange(oldState: state!)
        }

        didSet {
            subject.notifyStateDidChange(state: state!, oldState: oldValue!)
        }
    }

    private let subject = StoreSubject<State>()

    /// Initializes subject with the state
    /// - Parameter state: initial state
    public init(state: State) {

        self.state = state
    }

    /// Updates the state in the subject
    /// - Parameter state: new state
    public func updateState(state: State) {
        self.state = state
    }

    /// Adds state observer
    /// - Parameter observer: observer to be notified on state changes
    public func add<Observer>(observer: Observer) where Observer: StateObserver {
        if let observer = subject.add(observer: observer) { // new subcriber added with success
            observer.didChange(state: state!, oldState: nil)
        }
    }

    /// Removes state observer
    /// - Parameter observer: observer to remove
    public func remove<Observer>(observer: Observer) where Observer: StateObserver {
        subject.remove(observer: observer)
    }
}
