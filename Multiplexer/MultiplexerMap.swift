//
//  MultiplexerMap.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation

///
/// `MultiplexerMap<K, T>` is similar to `Multiplexer<T>` in many ways except it maintains a dictionary of objects of the same type. One example would be e.g. user profile objects in your social app.
/// The `K` generic paramter should conform to  `LosslessStringConvertible & Hashable`. The string convertibility requirement is because it simplifies the `Cacher`'s job of storing objects on disk or a database.
/// See README.md for a more detailed discussion.
///

/// MultiplexerMap base class that can be combined with a static `Cacher` implementation in a typealias.
open class MultiplexerMap<K: MuxKey, T: Codable>: MuxRepositoryProtocol {
	public typealias OnResult = (Result<T, Error>) -> Void

	///
	/// Instantiates a `MultiplexerMap<T>` object with a given `onKeyFetch` block. It's important to ensure that for each given object collection there is only one MultiplexerMap singleton in the app.
	/// - parameter onKeyFetch: this block should retrieve an object by its ID, possibly in an asynchronous manner, and return the result y calling the onResult method.
	///

	public convenience init(onKeyFetch: @escaping (K, @escaping OnResult) -> Void) {
		self.init(cacheID: String(describing: T.self), onKeyFetch: onKeyFetch)
	}

	public init(cacheID: String, onKeyFetch: @escaping (K, @escaping OnResult) -> Void) {
		self.cacher = Self.cacherClass.init()
		self.onKeyFetch = onKeyFetch
		self.cacheID = cacheID + ".Map"
	}

	///
	/// Performs a request either by calling the `onKeyFetch` block supplied in the constructor, or by returning the previously cached object, if available, by its ID passed as the `key` parameter. Multiple simultaneous calls to `request(...)` are handled by the MultiplexerMap so that only one `onKeyFetch` operation can be invoked for each object ID at a time, but all callers of `request(...)` will eventually receive the result, whether asynchronously or synchronously.
	/// - parameter key: object ID that will be passed to onKeyFetch
	/// - parameter completion: the callback block that will receive the result as `Result<T, Error>`.
	///

	public func request(key: K, completion: OnResult?) {
		let fetcher = fetcherForKey(key)

		// If the previous result is available in memory and is not expired, return straight away:
		if !fetcher.refreshFlag, let storedValue = fetcher.storedValue, !fetcher.isExpired(ttl: Self.timeToLive) {
			completion?(.success(storedValue))
			return
		}

		fetcher.refreshFlag = false

		// Append the completion block to the list of blocks to be notified when the result is available; fetch the object only if this is the first such completion block
		if fetcher.append(completion: completion) {
			return
		}

		// Call the abstract method that does the job of retrieving the object, presumably asynchronously; store the result in memory for subsequent use
		onKeyFetch(key) { (newResult) in
			switch newResult {
				case .success(let value):
					self.storeSuccess(key, value: value)
				case .failure(let error):
					self.storeFailure(key, error: error)
			}
		}
	}


	/// "Soft" refresh: the next call to `request(key:completion:)` will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh(key:)` does not have an immediate effect on any ongoing asynchronous requests for a given `key`.
	@discardableResult
	public func refresh(_ flag: Bool = true, key: K) -> Self {
		fetcherMap[key]?.refreshFlag = flag
		return self
	}


	/// "Soft" refresh of all stored elements: the next call to `request(key:completion:)` will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh(key:)` does not have an immediate effect on any ongoing asynchronous requests.
	public func refreshAll(_ flag: Bool = true) {
		fetcherMap.forEach { key, value in
			value.refreshFlag = flag
		}
	}


	/// Clears the last fetched result for a given `key` stored in memory; doesn't affect the disk-cached value. Can be used in low memory situations. Will trigger a full fetch on the next `request(key:completion:)` call.
	@discardableResult
	public func clearMemory(key: K) -> Self {
		fetcherMap.removeValue(forKey: key)
		return self
	}


	/// Clears the last fetched results for all keys stored in memory; doesn't affect the disk-cached values. Can be used in low memory situations. Will trigger a full fetch on the next `request(key:completion:)` call.
	@discardableResult
	public func clearMemory() -> Self {
		fetcherMap = [:]
		return self
	}


	/// Clears the cached value for a given `key` in memory and on disk. Will trigger a full fetch on the next `request(key:completion:)` call.
	@discardableResult
	public func clear(key: K) -> Self {
		cacher.clearCache(key: key, domain: cacheID)
		return clearMemory(key: key)
	}


	/// Clears the memory and disk caches for all keys. Will trigger a full fetch on the next `request(key:completion:)` call.
	@discardableResult
	public func clear() -> Self {
		cacher.clearCacheMap(domain: cacheID)
		return clearMemory()
	}


	/// Writes the previously cached objects to disk using the default cacher interface. For the `MultiplexerMap` class the default cacher is `JSONDiskCacher`.
	@discardableResult
	public func flush() -> Self {
		fetcherMap.forEach { (key, fetcher) in
			if fetcher.isDirty, let storedValue = fetcher.storedValue {
				cacher.saveToCache(storedValue, key: key, domain: cacheID)
				fetcher.isDirty = false
			}
		}
		return self
	}


	/// Overrides the currently memory-cached value or creates one for the given key. Useful when e.g. you update the object on the backend and the update method returns a fresh version of the object. Does not trigger completions.
	public func updateStoredValue(_ value: T, key: K) {
		fetcherForKey(key).updateStoredValue(value)
	}


	/// Defines in which cases a cached object should be returned to the caller in case of a failure to retrieve it in `onKeyFetch`. The time-to-live parameter will be ignored if this method returns `true`.
	open class func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }


	/// Determines when the Multiplexer should attempt to fetch a fresh copy of the object again. Applies to the memory cache only. Defaults to 30 minutes.
	open class var timeToLive: TimeInterval { MuxDefaultTTL }


	/// Cacher class, overrideable
	open class var cacherClass: Cacher<K, T>.Type { JSONDiskCacher.self }


	/// Internal method that is used by the caching interface. For `JSONDiskCacher` this becomes the directory name on disk in the local cache directory. Each object iss stored in the directory as a JSON file with the object ID as a file name, plus the `.json` extension. For DB-based cachers `cacheDomain` can be the table name. By default returns the object class name, e.g. for `MultiplexerMap<UserProfile>` the cache directory name will be "UserProfile.Map" in the cache directory.
	open var cacheID: String

	private typealias Fetcher = MultiplexFetcher<T>

	private let cacher: Cacher<K, T>

	private let onKeyFetch: (K, @escaping OnResult) -> Void

	private var fetcherMap: [K: Fetcher] = [:]

	private func fetcherForKey(_ key: K) -> Fetcher {
		var fetcher = fetcherMap[key]
		if fetcher == nil {
			fetcher = Fetcher()
			fetcherMap[key] = fetcher
		}
		return fetcher!
	}


	// MARK: - experimental (see MultiRequester)

	internal func storedValue(_ key: K) -> T? {
		fetcherMap[key].flatMap {
			!$0.isExpired(ttl: Self.timeToLive) ? $0.storedValue : nil
		}
	}


	internal func storeSuccess(_ key: K, value: T) {
		let fetcher = fetcherForKey(key)
		fetcher.triggerCompletions(result: .success(value), completionTime: Date().timeIntervalSinceReferenceDate)
	}


	@discardableResult
	internal func storeFailure(_ key: K, error: Error) -> T? {
		let fetcher = fetcherForKey(key)
		if Self.useCachedResultOn(error: error), let cachedValue = fetcher.storedValue ?? cacher.loadFromCache(key: key, domain: cacheID) {
			// Keep the loaded value in memory but don't touch completionTime so that a new attempt at retrieving can be made next time
			fetcher.triggerCompletions(result: .success(cachedValue), completionTime: nil)
			return cachedValue
		}
		else {
			fetcher.triggerCompletions(result: .failure(error), completionTime: nil)
			return nil
		}
	}
}
