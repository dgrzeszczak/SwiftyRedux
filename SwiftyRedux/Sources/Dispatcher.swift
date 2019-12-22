//
//  Dispatcher.swift
//  SwiftyRedux
//
//  Created by Dariusz Grzeszczak on 10/12/2019.
//  Copyright © 2019 Dariusz Grzeszczak. All rights reserved.
//

import Foundation


/// Object that is able to dishpatch actions
public protocol Dispatcher {
    /// Dishpatches an action.
    /// - Parameter action: action to dispach
    func dispatch(action: StoreAction)
}

/// Gives the option to dishpatch actions
@available(*, deprecated, renamed: "Dispatcher")
public typealias StoreActionDispatcher = Dispatcher
