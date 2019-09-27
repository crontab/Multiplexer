//
//  Debouncer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 27/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class Debouncer {

	init(delay: TimeInterval, onTrigger: @escaping () -> Void) {
		self.delay = delay
		self.onTrigger = onTrigger
	}

	func update() {
		guard onTrigger != nil else {
			return
		}
		counter += 1
		let capturedCounter = counter
		DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
			if let onTrigger = self.onTrigger, self.counter == capturedCounter {
				onTrigger()
			}
		}
	}

	func cancel() {
		onTrigger = nil
	}

	private var onTrigger: (() -> Void)?
	private var delay: TimeInterval
	private var counter: UInt64 = 0

	deinit {
		cancel()
		print("Debouncer: deinit")
	}
}
