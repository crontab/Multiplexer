//
//  Multiplexer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


let STANDARD_TTL: TimeInterval = 30 * 60

internal let jsonDecoder: JSONDecoder = { JSONDecoder() }()
internal let jsonEncoder: JSONEncoder = { JSONEncoder() }()


internal class MultiplexFetcher<T: Codable> {
	typealias Completion = (Result<T, Error>) -> Void

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


class MultiplexerBase<T: Codable>: MultiplexFetcher<T> {
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnFetch = (@escaping Completion) -> Void

	internal func request(refresh: Bool, completion: @escaping Completion, onFetch: @escaping OnFetch) {

		// If the previous result is available in memory and is not expired, return straight away:
		if !refresh && resultAvailable(ttl: timeToLive), let previousValue = previousValue {
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
				self.saveToCache(newValue)
				self.complete(result: newResult)

			case .failure(let error):
				if self.useCachedResultOn(error: error), let cachedValue = self.previousValue ?? self.loadFromCache() {
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
		clearCache()
	}

	// Caching: protected

	func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }

	var timeToLive: TimeInterval { STANDARD_TTL }

	var cacheKey: String? { String(describing: type(of: self)) }

	func loadFromCache() -> T? {
		if let cacheFileURL = cacheFileURL(create: false) {
			return try? jsonDecoder.decode(T.self, from: Data(contentsOf: cacheFileURL))
		}
		return nil
	}

	func saveToCache(_ result: T) {
		if let cacheFileURL = cacheFileURL(create: true) {
			DLOG("Multiplexer: storing to \(cacheFileURL)")
			try! jsonEncoder.encode(result).write(to: cacheFileURL, options: .atomic)
		}
	}

	func clearCache() {
		FileManager.removeRecursively(cacheFileURL(create: false))
	}

	func cacheFileURL(create: Bool) -> URL? {
		if let cacheKey = cacheKey {
			return FileManager.cacheDirectory(subDirectory: "Mux/", create: create).appendingPathComponent(cacheKey).appendingPathExtension("json")
		}
		return nil
	}
}


internal protocol MultiplexerProtocol {
	associatedtype T: Codable
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnFetch = (@escaping Completion) -> Void

	func request(refresh: Bool, completion: @escaping Completion, onFetch: @escaping OnFetch)

	// Required abstract entities:
	static var shared: Self { get }
	func onFetch(onResult: @escaping Completion)

	// Optional overrideables; see default implementations in MultiplexerBase
	func useCachedResultOn(error: Error) -> Bool
	var timeToLive: TimeInterval { get }
	var cacheKey: String? { get }
}


extension MultiplexerProtocol {
	func request(refresh: Bool, completion: @escaping Completion) {
		request(refresh: refresh, completion: completion, onFetch: onFetch)
	}
}


typealias Multiplexer<T: Codable> = MultiplexerBase<T> & MultiplexerProtocol
