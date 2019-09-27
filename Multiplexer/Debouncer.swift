//
//  Debouncer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 27/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class Debouncer<T> {

	init(initialValue: T, delay: TimeInterval, onTrigger: @escaping (T) -> Void) {
		self.delay = delay
		self.value = initialValue
		self.onTrigger = onTrigger
	}

	private (set) var value: T

	func update(newValue: T) {
		value = newValue
		if let onTrigger = onTrigger {
			self.workItem?.cancel()
			var workItem: DispatchWorkItem!
			workItem = DispatchWorkItem {
				if !workItem.isCancelled {
					onTrigger(self.value)
				}
			}
			self.workItem = workItem
			DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
		}
	}

	func cancel() {
		workItem?.cancel()
		workItem = nil
	}

	private var onTrigger: ((T) -> Void)?
	private var delay: TimeInterval
	private var workItem: DispatchWorkItem?

	deinit {
		workItem?.cancel()
		workItem = nil
		print("Debouncer: deinit")
	}
}
