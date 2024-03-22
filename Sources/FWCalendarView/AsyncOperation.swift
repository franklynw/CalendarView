//
//  AsyncOperation.swift
//  
//
//  Created by Franklyn on 22/03/2024.
//

import Foundation


class AsyncOperation: Operation {

    enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }

    var state: State = .isReady {
        willSet {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }

    public override var isAsynchronous: Bool {
        return true
    }
    public override var isExecuting: Bool {
        return state == .isExecuting
    }
    public override var isFinished: Bool {
        if isCancelled && state != .isExecuting {
            return true
        }
        return state == .isFinished
    }

    private let task: (Operation, @escaping () -> ()) -> ()

    
    /// Initialiser
    /// - Parameter task: the task to queue, which has a task for execution and a finished closure to be called by the task when it's done
    public init(task: @escaping (Operation, @escaping () -> ()) -> ()) {
        self.task = task
        super.init()
    }

    public override func start() {

        guard !isCancelled else {
            return
        }

        state = .isExecuting

        task(self) { [weak self] in
            self?.state = .isFinished
        }
    }
}
