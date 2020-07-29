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


// MARK: - Synchronization


@inlinable
public func Async(_ execute: @escaping () -> Void) {
	DispatchQueue.main.async(execute: execute)
}


@inlinable
public func AsyncAfter(_ after: TimeInterval, _ execute: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: execute)
}
