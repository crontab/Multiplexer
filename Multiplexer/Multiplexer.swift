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

public typealias Multiplexer<T: Codable> = MultiplexerBase<T, JSONDiskCacher<String, T>>


public var MuxDefaultTTL: TimeInterval = 30 * 60


/// Internal class that's reused in `MultiplexerBase` and `MultiplexerMapBase`
public class MultiplexFetcher<T: Codable> {
	public typealias OnResult = (Result<T, Error>) -> Void

	private var completions: [OnResult?] = []
	private var completionTime: TimeInterval = 0

	internal var isDirty: Bool = false
	internal var refreshFlag: Bool = false


	internal func isExpired(ttl: TimeInterval) -> Bool {
		return Date().timeIntervalSinceReferenceDate > completionTime + ttl
	}


	internal func append(completion: OnResult?) -> Bool {
		completions.append(completion)
		return completions.count > 1
	}


	internal func triggerCompletions(result: Result<T, Error>, completionTime: TimeInterval?) {
		switch result {

		case .success(let value):
			// If the completion time was specified, make sure it's newer than the previos one and update the value
			if let completionTime = completionTime {
				self.completionTime = completionTime
			}
			storedValue = value

		case .failure:
			clearMemory()
		}

		while !completions.isEmpty {
			completions.removeFirst()?(result)
		}
	}


	/// Last good value returned by the fetcher; can be used in situations where requesting the result via a callback is not feasible or practical and an optimistic assumption can be made that the result is likely already available. Use with care.
	public private(set) var storedValue: T? {
		didSet { isDirty = storedValue != nil }
	}


	/// Clears the last fetched result stored in memory; doesn't affect the disk-cached one. Can be used in low memory situations. Will trigger a full fetch on the next `request(completion:)` call.
	@discardableResult
	public func clearMemory() -> Self {
		completionTime = 0
		storedValue = nil
		return self
	}
}


/// Multiplexer base class that can be combined with a static `Cacher` implementation in a typealias.
public class MultiplexerBase<T: Codable, C: Cacher>: MultiplexFetcher<T>, MuxRepositoryProtocol {

	///
	/// Instantiates a `Multiplexer<T>` object with a given `onFetch` block. It's important to ensure that for each given singular object there is only one Multiplexer singleton in the app.
	/// - parameter onFetch: this block should retrieve an object, possibly in an asynchronous manner, and return the result y calling the onResult method.
	///

	public init(onFetch: @escaping (@escaping OnResult) -> Void) {
		self.onFetch = onFetch
	}

	///
	/// Performs a request either by calling the `onFetch` block supplied in the multiplexer's constructor, or by returning the previously cached object, if available. Multiple simultaneous calls to `request(...)` are handled by the Multiplexer so that only one `onFetch` operation can be invoked at a time, but all callers of `request(...)` will eventually receive the result, whether asynchronously or synchronously.
	/// - parameter completion: the callback block that will receive the result as `Result<T, Error>`.
	///

	public func request(completion: OnResult?) {

		// If the previous result is available in memory and is not expired, return straight away:
		if !refreshFlag, let storedValue = storedValue, !isExpired(ttl: Self.timeToLive) {
			completion?(.success(storedValue))
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

			case .success:
				self.triggerCompletions(result: newResult, completionTime: Date().timeIntervalSinceReferenceDate)

			case .failure(let error):
				if Self.useCachedResultOn(error: error), let cachedValue = self.storedValue ?? C.loadFromCache(key: self.cacheID, domain: nil) {
					// Keep the loaded value in memory but don't touch completionTime so that a new attempt at retrieving can be made next time
					self.triggerCompletions(result: .success(cachedValue), completionTime: nil)
				}
				else {
					self.triggerCompletions(result: newResult, completionTime: nil)
				}
			}
		}
	}


	/// "Soft" refresh: the next call to `request(completion:)` will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh()` does not have an immediate effect on any ongoing asynchronous requests.
	@discardableResult
	public func refresh(_ flag: Bool = true) -> Self {
		refreshFlag = flag
		return self
	}


	/// Clears the memory and disk caches. Will trigger a full fetch on the next `request(completion:)` call.
	@discardableResult
	public func clear() -> Self {
		C.clearCache(key: cacheID, domain: nil)
		return clearMemory()
	}


	/// Writes the previously cached object to disk using the default cacher interface. For the `Multiplexer` class the default cacher is `JSONDiskCacher`.
	@discardableResult
	public func flush() -> Self {
		if isDirty, let storedValue = storedValue {
			C.saveToCache(storedValue, key: cacheID, domain: nil)
			isDirty = false
		}
		return self
	}


	/// Defines in which cases a cached object should be returned to the caller in case of a failure to retrieve it in `onFetch`. The time-to-live parameter will be ignored if this method returns `true`.
	public class func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }


	/// Determines when the Multiplexer should attempt to fetch a fresh copy of the object again. Applies to the memory cache only. Defaults to 30 minutes.
	public class var timeToLive: TimeInterval { MuxDefaultTTL }


	/// Internal method that is used by the caching interface. For `JSONDiskCacher` this becomes the file name on disk in the local cache directory, plus the `.json` extension. For DB-based cachers this can be a index key for retrieving the object from the table of global objects. By default returns the object class name, e.g. for `Multiplexer<UserProfile>` the file name will be "UserProfile.json" in the cache directory.
	public var cacheID: String { String(describing: T.self) }


	private let onFetch: (@escaping OnResult) -> Void
}
