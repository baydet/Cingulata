//
//  Operation.swift
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 10/3/15.
//  Copyright © 2015 baydet. All rights reserved.
//

import Foundation

extension NSLock {
    func withCriticalScope<T>(@noescape block: Void -> T) -> T {
        lock()
        let value = block()
        unlock()
        return value
    }
}

class Operation: NSOperation {

    //MARK: operaton state management

    class func keyPathsForValuesAffectingIsReady() -> Set<NSObject> {
        return ["state"]
    }

    class func keyPathsForValuesAffectingIsExecuting() -> Set<NSObject> {
        return ["state"]
    }

    class func keyPathsForValuesAffectingIsFinished() -> Set<NSObject> {
        return ["state"]
    }

    private enum State: Int {
        case Initialized
        case Executing
        case Finished

        func canTransitionToState(target: State) -> Bool {
            switch (self, target) {
            case (.Initialized, .Executing):
                return true
            case (.Executing, .Finished):
                return true
            default:
                return false
            }
        }
    }

    private var _state = State.Initialized
    private let stateLock = NSLock()

    internal var errors : [ErrorType] = []
    public var operationErrors: [ErrorType] { get {
        return errors
    }}

    private var state: State {
        get {
            return stateLock.withCriticalScope {
                _state
            }
        }
        set(newState) {
            willChangeValueForKey("state")
            stateLock.withCriticalScope { Void -> Void in
                if _state == .Finished {
                    return
                }

                assert(_state.canTransitionToState(newState), "Performing invalid state transition.")
                _state = newState
            }
            didChangeValueForKey("state")
        }
    }

    override var finished: Bool {
        return state == .Finished
    }


    //MARK: execution

    func execute() {
        finish()
    }

    func finish() {
        state = .Finished
    }

    //MARK: NSOperation methods

    override func main() {
        state = .Executing

        execute()
    }

}
