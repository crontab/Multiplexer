//
//  Multiplexer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


private let STANDARD_TTL: TimeInterval = 30 * 60

private let jsonDecoder: JSONDecoder = { JSONDecoder() }()
private let jsonEncoder: JSONEncoder = { JSONEncoder() }()


internal protocol MultiplexerBaseProtocol {
	associatedtype T: Codable
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnFetch = (@escaping Completion) -> Void

	func request(refresh: Bool, completion: @escaping Completion, onFetch: @escaping OnFetch)
}


class MultiplexerBase<T: Codable>: MultiplexerBaseProtocol {
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnFetch = (@escaping Completion) -> Void

	internal func request(refresh: Bool, completion: @escaping Completion, onFetch: @escaping OnFetch) {

		// If the previous result is available in memory and is not expired, return straight away:
		if !refresh && resultAvailable, let previousValue = previousValue {
			completion(.success(previousValue))
			return
		}

		// Append the completion block to the list of blocks to be notified when the result is available; fetch the object only if this is the first such completion block
		completions.append(completion)
		if completions.count > 1 {
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
				self.completionTime = nil
				if self.useCachedResultOn(error: error), let cachedValue = self.previousValue ?? self.loadFromCache() {
					self.previousValue = cachedValue
					self.complete(result: .success(cachedValue))
				}
				else {
					self.previousValue = nil
					self.complete(result: newResult)
				}
			}
		}
	}

	func clearMemory() {
		completionTime = nil
		previousValue = nil
	}

	func clear() {
		clearMemory()
		clearCache()
	}


	// Protected

	func useCachedResultOn(error: Error) -> Bool {
		if (error as NSError).domain == NSURLErrorDomain {
			return [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost].contains((error as NSError).code)
		}
		return false
	}

	var timeToLive: TimeInterval {
		return STANDARD_TTL
	}


	// Private

	private var completions: [Completion] = []
	private var completionTime: TimeInterval?
	private var previousValue: T?

	private var resultAvailable: Bool {
		guard let completionTime = completionTime else {
			return false
		}
		return Date().timeIntervalSinceReferenceDate <= completionTime + timeToLive
	}

	private func complete(result: Result<T, Error>) {
		while !completions.isEmpty {
			completions.removeFirst()(result)
		}
	}
}


extension MultiplexerBase {

	var cacheKey: String? {
		return String(describing: type(of: self))
	}

	var cacheDomain: String? {
		return nil
	}

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
		if let cacheFileURL = cacheFileURL(create: false) {
			FileManager.removeRecursively(cacheFileURL)
		}
	}

	private func cacheFileURL(create: Bool) -> URL? {
		if let cacheKey = cacheKey {
			return FileManager.cacheDirectory(subDirectory: "Mux/" + (cacheDomain ?? ""), create: create).appendingPathComponent(cacheKey).appendingPathExtension("json")
		}
		return nil
	}
}


protocol MultiplexerProtocol: MultiplexerBaseProtocol {
	func onFetch(onResult: @escaping (Result<T, Error>) -> Void) // required abstract

	func useCachedResultOn(error: Error) -> Bool
	var timeToLive: TimeInterval { get }
	var cacheKey: String? { get }
	var cacheDomain: String? { get }
}


extension MultiplexerProtocol {
	func request(refresh: Bool, completion: @escaping Completion) {
		request(refresh: refresh, completion: completion, onFetch: onFetch)
	}
}


typealias Multiplexer<T: Codable> = MultiplexerBase<T> & MultiplexerProtocol

