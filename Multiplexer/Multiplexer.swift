//
//  Multiplexer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation

/**
`Multiplexer<T>` is an asynchronous, callback-based caching facility for client apps. Each multiplxer instance can manage retrieval and caching of one object of type `T: Codable`, therefore it is best to define each multiplexer instance in your app as a singleton.

For each multiplexer singleton you define a block that implements asynchronous retrieval of the object, which most of the time would be a network request, e.g. to your backend system.

A multiplexer singleton guarantees that there will only be one fetch/retrieval operation made, and that subsequently a memory-cached object will be returned to the callers of its `request()` method , unless the cached object expires according to the `timeToLive` setting (defaults to 30 minutes). Additionally, `Multiplexer` can store the object on disk - see `flush()` and also the discussion on `request(refresh:completion:)`.

Suppose you have a `UserProfile` class and a method of retrieving the current user's profile object from the backend, whose signature looks like this:

	class Backend {
		static func fetchMyProfile(completion: (Result<UserProfile, Error>) -> Void)
	}

Then an instantiation of a multiplexer singleton may look like:

	let myProfile = Multiplexer<UserProfile>(onFetch: { onResult in
		Backend.fetchMyProfile(onResult)
	})

Or even shorter:

	let myProfile = Multiplexer<UserProfile>(onFetch: Backend.fetchMyProfile)

To use `myProfile` to fetch the profile object, you call the `request(refresh:completion:)` method like so:

	myProfile.request(refresh: false) { result in
		switch result {
		case .failure(let error)
			print("Error:", error)
		case .success(let profile)
			print("My profile:", profile)
		}
	}

When called for the first time, `request(...)` calls your `onFetch` block, returns it to your completion block as `Result<T, Error>`, and also caches the result in memory. Subsequent calls to `request(...)` will return immediately with the stored object. The `refresh` parameter tells the multiplexer to try to retrieve the object again, similarly to the browser's Cmd-R function.

Most importantly, `request(...)` can handle multiple simultaneous calls and ensures only one `onFetch` operation is initiated at a time.

See also:

- `init(onFetch: @escaping (@escaping OnResult) -> Void)`
- `func request(refresh: Bool, completion: @escaping OnResult)`
- `func flush()`
- `MultiplexerMap<T>` interface

### Caching

By default, `Multiplexer<T>` can store objects as JSON files in the local cache directory. This is done by explicitly calling `flush()` on the multiplexer object, or alternatively `flushAll()` on the global repository MuxRepository if the object is registered there.

In the current implementation, the objects stored on disk can be reused only in one case: when your `onFetch` fails due to a connectivity problem. This behavior is defined in the `useCachedResultOn(error:)` class method that can be overridden in your subclass of `Multiplexer`. For the memory cache, the expiration logic is defined by the class variable `timeToLive`, which defaults to 30 minutes and can also be overridden in your subclass.

The storage method can be changed by defining a class that conforms to `Cacher`, possibly with a generic parameter for the basic object type. For example you can define your own cacher that uses CoreData, called `CDCacher<T>`, then define your new multiplexer class as:

	typealias CDMultiplexer<T: Codable> = MultiplexerBase<T, CDCacher<T>>

At run time, you can invalidate the cached object using one of the following methods:

- "Soft refresh": use the `refresh` argument in your call to `request(refresh:completion:)`: the multiplexer will attempt to fetch the object again, but will not discard the existing cached objects in memory or on disk. In case of a failure the older cached object may be used again as a result.
- "Hard refresh": call `clear()` to discard both memory and disk caches for the given object. The next call to `request(...)` will attempt to fetch the object and will fail in case of an error.

See also:

- `flush()`
- `clear()`
- `Cacher` interface
- `MuxRepository` interface

*/
typealias Multiplexer<T: Codable> = MultiplexerBase<T, JSONDiskCacher<T>>


let STANDARD_TTL: TimeInterval = 30 * 60


/// This is an internal class that's reused in `MultiplexerBase` and `MultiplexerMapBase`
internal class MultiplexFetcher<T: Codable> {
	typealias OnResult = (Result<T, Error>) -> Void

	internal var completions: [OnResult] = []
	internal var completionTime: TimeInterval = 0
	internal var previousValue: T?

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

	func clearMemory() {
		completionTime = 0
		previousValue = nil
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


	/// Performs a request either by calling the `onFetch` block supplied in the multiplexer's constructor, or by returning the previously cached object, if available. Multiple simultaneous calls to `request(...)` are handled by the Multiplexer so that only one `onFetch` operation can be invoked at a time, but all callers of `request(...)` will eventually receive the result, whether asynchronously or synchronously.
	/// - parameter refresh: whether to perform a "soft" refresh. Most of the time you will set it to false unless, e.g. you have updated the remote object and want to receive a fresher copy of it.
	/// - parameter completion: the callback block that will receive the result as `Result<T, Error>`.
	func request(refresh: Bool, completion: @escaping OnResult) {

		// If the previous result is available in memory and is not expired, return straight away:
		if !refresh, let previousValue = previousValue, !isExpired(ttl: Self.timeToLive) {
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


	/// Discards the memory and disk caches for the given object
	func clear() {
		clearMemory()
		C.clearCache(key: Self.cacheKey, domain: nil)
	}


	/// Writes the previously cached object to disk using the default cacher interface. For the `Multiplexer` class the default cacher is `JSONDiskCacher`.
	func flush() {
		if let previousValue = previousValue {
			C.saveToCache(previousValue, key: Self.cacheKey, domain: nil)
		}
	}


	/// Defines in which cases a cached object should be returned to the caller in case of a failure to retrieve it in `onFetch`. The time-to-live parameter will be ignored if this method returns `true`.
	class func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }


	/// Determines when the Multiplexer should attempt to fetch a fresh copy of the object again. Applies to the memory cache only. Defaults to 30 minutes.
	class var timeToLive: TimeInterval { STANDARD_TTL }


	/// Internal method that is used by the caching interface. For `JSONDiskCacher` this becomes the file name on disk in the local cache directory, plus the `.json` extension. For DB-based cachers this can be a index key for retrieving the object from the table of global objects. By default returns the object class name, e.g. for `Multiplexer<UserProfile>` the file name will be "UserProfile.json" in the cache directory.
	class var cacheKey: String { String(describing: T.self) }


	private let onFetch: (@escaping OnResult) -> Void
}
