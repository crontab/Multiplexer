//
//  Multiplexer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


extension Error {
	var isConnectivityError: Bool {
		if (self as NSError).domain == NSURLErrorDomain {
			return [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost].contains((self as NSError).code)
		}
		return false
	}
}


internal class MultiplexFetcher<T: Codable> {
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnFetch = (@escaping Completion) -> Void

	internal var completions: [Completion] = []
	internal var completionTime: TimeInterval?
	internal var previousValue: T?

	internal func resultAvailable(ttl: TimeInterval) -> Bool {
		guard let completionTime = completionTime else {
			return false
		}
		return Date().timeIntervalSinceReferenceDate <= completionTime + ttl
	}

	internal func append(completion: @escaping Completion) -> Bool {
		completions.append(completion)
		return completions.count > 1
	}

	internal func complete(result: Result<T, Error>) {
		while !completions.isEmpty {
			completions.removeFirst()(result)
		}
	}

	func clearMemory() {
		completionTime = nil
		previousValue = nil
	}
}


class MultiplexerBase<T: Codable, C: Cacher>: MultiplexFetcher<T> {

	init(onFetch: @escaping OnFetch) {
		self.onFetch = onFetch
	}

	func request(refresh: Bool, completion: @escaping Completion) {

		// If the previous result is available in memory and is not expired, return straight away:
		if !refresh && resultAvailable(ttl: C.timeToLive), let previousValue = previousValue {
			completion(.success(previousValue))
			return
		}

		// Append the completion block to the list of blocks to be notified when the result is available; fetch the object only if this is the first such completion block
		if append(completion: completion) {
			return
		}

		// Call the abstract method that does the job of retrieving the object, presumably asynchronously; store the result in cache for subsequent use
		onFetch { (newResult) in
			switch newResult {

			case .success(let newValue):
				self.completionTime = Date().timeIntervalSinceReferenceDate
				self.previousValue = newValue
				C.saveToCache(newValue)
				self.complete(result: newResult)

			case .failure(let error):
				if C.useCachedResultOn(error: error), let cachedValue = self.previousValue ?? C.loadFromCache() {
					self.previousValue = cachedValue
					self.complete(result: .success(cachedValue))
				}
				else {
					self.completionTime = nil
					self.previousValue = nil
					self.complete(result: newResult)
				}
			}
		}
	}

	func clear() {
		clearMemory()
		C.clearCache()
	}

	private let onFetch: OnFetch
}


typealias Multiplexer<T: Codable> = MultiplexerBase<T, JSONDiskCacher<T>>
