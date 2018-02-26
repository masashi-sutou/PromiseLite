//
//  PromiseLite.swift
//  PromiseLite
//
//  Created by 須藤将史 on 2018/02/26.
//
//  Copyright © 2015年 yashigani. All rights reserved.
//  Copyright © 2018年 須藤将史. All rights reserved.
//

import Dispatch

internal enum State {
    case pending
    case resolved
    case rejected
}

internal enum Result<T> {
    case undefined
    case value(T)
    case error(Error)
}

private let queue = DispatchQueue(label: "promiseLite.swift.worker", attributes: .concurrent)

public final class PromiseLite<T> {
    
    public typealias Resolver = (T) -> ()
    public typealias Rejector = (Error) -> ()
    public typealias Executor = (_ resolve: @escaping Resolver, _ reject: @escaping Rejector) -> ()
    
    // MARK: - property
    
    private(set) var state: State = .pending {
        didSet {
            if case .pending = oldValue {
                switch (state, result) {
                case (.resolved, .value(let value)):
                    resolve?(value)
                case (.rejected, .error(let error)):
                    reject?(error)
                default: ()
                }
            }
        }
    }
    private(set) var result: Result<T> = .undefined
    private var resolve: ((T) -> ())?
    private var reject: ((Error) -> ())?
    
    // MARK: - initalizar
    
    public init(_ executor: @escaping Executor) {
        queue.async {
            executor(self.onResolved, self.onRejected)
        }
    }
    
    public init(_ promiseLite: PromiseLite<T>) {
        if case .pending = promiseLite.state {
            let semaphore = DispatchSemaphore(value: 0)
            promiseLite.then(onResolved: { _ in
                semaphore.signal()
            }).catchError(onRejected: { _ in
                semaphore.signal()
            })
            semaphore.wait()
        }
        
        switch (promiseLite.state, promiseLite.result) {
        case (.resolved, .value(let value)):
            onResolved(value: value)
        case (.rejected, .error(let error)):
            onRejected(error: error)
        default:
            assertionFailure()
        }
    }
    
    public convenience init(_ executor: @autoclosure @escaping () throws -> T) {
        self.init { resolve, reject in
            do {
                let v: T = try executor()
                resolve(v)
            } catch {
                reject(error)
            }
        }
    }
    
    // MARK: - state transition
    
    private func onResolved(value: T) {
        if case .pending = state {
            result = .value(value)
            state = .resolved
        }
    }
    
    private func onRejected(error: Error) {
        if case .pending = state {
            result = .error(error)
            state = .rejected
        }
    }
    
    @discardableResult
    public static func resolve(value: T) -> PromiseLite<T> {
        let semaphore = DispatchSemaphore(value: 0)
        let promiseLite = PromiseLite<T> { (resolve, _) in
            resolve(value)
            semaphore.signal()
        }
        semaphore.wait()
        return promiseLite
    }
    
    @discardableResult
    public static func reject(error: Error) -> PromiseLite<T> {
        let semaphore = DispatchSemaphore(value: 0)
        let promiseLite = PromiseLite<T> { _, reject in
            reject(error)
            semaphore.signal()
        }
        semaphore.wait()
        return promiseLite
    }
    
    // MARK: - operator
    
    @discardableResult
    private func then<U>(onResolved: @escaping (T) -> U, onRejected: ((Error) -> ())?) -> PromiseLite<U> {
        return PromiseLite<U> { _resolve, _reject in
            switch (self.state, self.result) {
            case (.pending, _):
                let resolve = self.resolve
                self.resolve = {
                    resolve?($0)
                    _resolve(onResolved($0))
                }
                let reject = self.reject
                self.reject = {
                    reject?($0)
                    _reject($0)
                    onRejected?($0)
                }
            case (.resolved, .value(let value)):
                _resolve(onResolved(value))
            case (.rejected, .error(let error)):
                _reject(error)
                onRejected?(error)
            default:
                assertionFailure()
            }
        }
    }
    
    @discardableResult
    public func then<U>(onResolved: @escaping (T) -> U, onRejected: @escaping (Error) -> ()) -> PromiseLite<U> {
        return then(onResolved: onResolved, onRejected: .some(onRejected))
    }
    
    @discardableResult
    public func then<U>(onResolved: @escaping (T) -> U) -> PromiseLite<U> {
        return then(onResolved: onResolved, onRejected: nil)
    }
    
    @discardableResult
    public func catchError(onRejected: @escaping (Error) -> ()) -> PromiseLite<T> {
        return then(onResolved: { $0 }, onRejected: onRejected)
    }
    
    @discardableResult
    public static func all(promiseLites: [PromiseLite<T>]) -> PromiseLite<[T]> {
        return PromiseLite<[T]> { (resolve: @escaping ([T]) -> (), reject: @escaping (Error) -> ()) in
            promiseLites.forEach {
                $0.then(onResolved: { v -> T in
                    if promiseLites.filter({ $0.state == .resolved}).count == promiseLites.count {
                        let value: [T] = promiseLites.flatMap {
                            if case .value(let v) = $0.result {
                                return v
                            } else {
                                return nil
                            }
                        }
                        resolve(value)
                    }
                    return v
                }, onRejected: {
                    reject($0)
                })
            }
        }
    }
    
    @discardableResult
    public static func race(promiseLites: [PromiseLite<T>]) -> PromiseLite<T> {
        return PromiseLite<T> { (resolve: @escaping (T) -> (), reject: @escaping (Error) -> ()) in
            promiseLites.forEach {
                $0.then(onResolved: { v in resolve(v) }, onRejected: reject)
            }
        }
    }
}
