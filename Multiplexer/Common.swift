//
//  Common.swift
//
//  Created by Hovik Melikyan on 29/07/2020.
//  Copyright © 2020 Hovik Melikyan. All rights reserved.
//

import Foundation


@inlinable
internal func debugOnly(_ body: () -> Void) {
	assert({ body(); return true }())
}


@inlinable
public func DLOG(_ s: String) {
	debugOnly {
		print(s)
	}
}


// MARK: - Synchronization shortcuts


/// Asynchronously execute a block on the main thread
@inlinable
public func Async(_ execute: @escaping () -> Void) {
	DispatchQueue.main.async(execute: execute)
}


/// Execute on a new thread with a given QoS
@inlinable
public func AsyncGlobal(qos: DispatchQoS.QoSClass = .default, _ execute: @escaping () -> Void) {
	DispatchQueue.global(qos: qos).async(execute: execute)
}


/// Execute on the main thread with a delay
@inlinable
public func Async(after: TimeInterval, _ execute: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: execute)
}


/// Execute a work item on the main thread with a delay; work item can be cancelled
@inlinable
public func Async(after: TimeInterval, _ execute: DispatchWorkItem) {
	DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: execute)
}
