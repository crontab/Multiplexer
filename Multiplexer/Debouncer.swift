//
//  Debouncer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 27/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation

///
/// `Debouncer` triggers execution of a block after a specified delay, but in addition it also postpones the execution every time `touch()` is called. This can be useful in GUI apps when e.g. a network request should be delayed while the user types in the search field. A Debouncer instance should be retained in your GUI object to be useful, therefore beware of cyclic references that your execution block can introduce. The `touch()` method should be called at least once for the block to be executed.
/// See README.md for some examples.
///
public class Debouncer: DebouncerVar<_Empty> {

	/// Create a Debouncer instance that will trigger execution of the block after `delay` seconds. The block won't be executed unless `touch()` is called at least once.
	public init(delay: TimeInterval, execute: @escaping (_Empty) -> Void) {
		super.init(.init(), delay: delay, execute: execute)
	}
}


/// A variant of Debouncer, `DebouncerVar<T>` adds a value of type T that triggers `touch()` every time the value is assigned, and if the new value is different from the previous one.
public class DebouncerVar<T: Equatable> {

	/// Create a DebouncerVar<T> instance that will trigger execution of the block after `delay` seconds on each value update. The block won't be executed unless the value is assigned at least once and if the new value is different from the initial one.
	public init(_ initialValue: T, delay: TimeInterval, execute: @escaping (T) -> Void) {
		self.delay = delay
		self.execute = execute
		_value = initialValue
	}

	/// Cancel any pending execution on postpone it for further `delay` seconds.
	public func touch() {
		guard execute != nil else {
			return
		}
		counter += 1
		let capturedCounter = counter
		DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
			if let execute = self.execute, self.counter == capturedCounter {
				execute(self._value)
			}
		}
	}

	deinit {
		execute = nil
	}

	/// Assignment to this value triggers `touch()` if the new value differs from the previous one.
	public var value: T {
		get { _value }
		set {
			if _value != newValue {
				_value = newValue
				touch()
			}
		}
	}

	private var _value: T
	private var execute: ((T) -> Void)?
	private var delay: TimeInterval
	private var counter: UInt64 = 0
}


public struct _Empty: Equatable {
	public static func == (a: _Empty, b: _Empty) -> Bool { true }
}
