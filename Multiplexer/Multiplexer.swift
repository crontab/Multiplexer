//
//  Multiplexer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation

///
/// `Multiplexer<T>` is an asynchronous, callback-based caching facility for client apps. Each multiplxer instance can manage retrieval and caching of one object of type `T: Codable`, therefore it is best to define each multiplexer instance in your app as a singleton.
/// For each multiplexer singleton you define a block that implements asynchronous retrieval of the object, which in your app will likely be a network request, e.g. to your backend system.
/// See README.md for a more detailed discussion.
///

typealias Multiplexer<T: Codable> = MultiplexerBase<T, JSONDiskCacher<T>>


let STANDARD_TTL: TimeInterval = 30 * 60


/// Internal class that's reused in `MultiplexerBase` and `MultiplexerMapBase`
internal class MultiplexFetcher<T: Codable> {
	typealias OnResult = (Result<T, Error>) -> Void

	internal var completions: [OnResult] = []
	internal var completionTime: TimeInterval = 0
	internal var previousValue: T?
	internal var refreshFlag: Bool = false

	internal func isExpired(ttl: TimeInterval) -> Bool {
		return Date().timeIntervalSinceReferenceDate > completionTime + ttl
	}

	internal func append(completion: @escaping OnResult) -> Bool {
		completions.append(completion)
		return completions.count > 1
	}

	internal func complete(result: Result<T, Error>) {
		while !completions.isEmpty {
			completions.removeFirst()(result)
		}
	}

	@discardableResult
	func clearMemory() -> Self {
		completionTime = 0
		previousValue = nil
		return self
	}
}


/// Multiplexer base class that can be combined with a static `Cacher` implementation in a typealias.
class MultiplexerBase<T: Codable, C: Cacher>: MultiplexFetcher<T>, MuxRepositoryProtocol {

	///
	/// Instantiates a `Multiplexer<T>` object with a given `onFetch` block. It's important to ensure that for each given singular object there is only one Multiplexer singleton in the app.
	/// - parameter onFetch: this block should retrieve an object, possibly in an asynchronous manner, and return the result y calling the onResult method.
	///

	init(onFetch: @escaping (@escaping OnResult) -> Void) {
		self.onFetch = onFetch
	}

	///
	/// Performs a request either by calling the `onFetch` block supplied in the multiplexer's constructor, or by returning the previously cached object, if available. Multiple simultaneous calls to `request(...)` are handled by the Multiplexer so that only one `onFetch` operation can be invoked at a time, but all callers of `request(...)` will eventually receive the result, whether asynchronously or synchronously.
	/// - parameter completion: the callback block that will receive the result as `Result<T, Error>`.
	///

	func request(completion: @escaping OnResult) {

		// If the previous result is available in memory and is not expired, return straight away:
		if !refreshFlag, let previousValue = previousValue, !isExpired(ttl: Self.timeToLive) {
			completion(.success(previousValue))
			return
		}

		refreshFlag = false

		// Append the completion block to the list of blocks to be notified when the result is available; fetch the object only if this is the first such completion block
		if append(completion: completion) {
			return
		}

		// Call the abstract method that does the job of retrieving the object, presumably asynchronously; store the result in memory for subsequent use
		onFetch { (newResult) in
			switch newResult {

			case .success(let newValue):
				self.completionTime = Date().timeIntervalSinceReferenceDate
				self.previousValue = newValue
				self.complete(result: newResult)

			case .failure(let error):
				if Self.useCachedResultOn(error: error), let cachedValue = self.previousValue ?? C.loadFromCache(key: Self.cacheKey, domain: nil) {
					// Keep the loaded value in memory but don't touch completionTime so that a new attempt at retrieving can be made next time
					self.previousValue = cachedValue
					self.complete(result: .success(cachedValue))
				}
				else {
					self.clearMemory()
					self.complete(result: newResult)
				}
			}
		}
	}


	/// "Soft" refresh: the next call to `request(completion:)` will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh()` does not have an immediate effect on any ongoing asynchronous requests.
	@discardableResult
	func refresh() -> Self {
		refreshFlag = true
		return self
	}


	/// Discards the memory and disk caches for the given object
	@discardableResult
	func clear() -> Self {
		C.clearCache(key: Self.cacheKey, domain: nil)
		return clearMemory()
	}


	/// Writes the previously cached object to disk using the default cacher interface. For the `Multiplexer` class the default cacher is `JSONDiskCacher`.
	@discardableResult
	func flush() -> Self {
		if let previousValue = previousValue {
			C.saveToCache(previousValue, key: Self.cacheKey, domain: nil)
		}
		return self
	}


	/// Defines in which cases a cached object should be returned to the caller in case of a failure to retrieve it in `onFetch`. The time-to-live parameter will be ignored if this method returns `true`.
	class func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }


	/// Determines when the Multiplexer should attempt to fetch a fresh copy of the object again. Applies to the memory cache only. Defaults to 30 minutes.
	class var timeToLive: TimeInterval { STANDARD_TTL }


	/// Internal method that is used by the caching interface. For `JSONDiskCacher` this becomes the file name on disk in the local cache directory, plus the `.json` extension. For DB-based cachers this can be a index key for retrieving the object from the table of global objects. By default returns the object class name, e.g. for `Multiplexer<UserProfile>` the file name will be "UserProfile.json" in the cache directory.
	class var cacheKey: String { String(describing: T.self) }


	private let onFetch: (@escaping OnResult) -> Void
}
