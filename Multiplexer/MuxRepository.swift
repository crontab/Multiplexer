//
//  MuxRepository.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 28/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


internal protocol MuxRepositoryProtocol: class {
	func flush() // store memory cache on disk
	func clearMemory() // free some memory; note that this will force a multiplexer to make a new fetch request next time
	func clear() // clear all memory and disk caches
}


/// Global repository of multiplexers. Multiplexer singletons can be registered here to be included in `clearAll()` and `flushAll()` operations.
class MuxRepository {

	/// Clears caches for all registered Multiplexer objects. Useful when e.g. the user signs out of the app and there should be no traces left of the previously retrieved backend objects.
	static func clearAll() {
		repo.values.forEach { $0.clear() }
	}

	/// Writes all memory-cached objects to disk for each of the registered Multiplexer objects. The default implementations of `Multiplexer<T>` and `MultiplexerMap<T>` use simple file-based JSON caching. `flushAll()` can be called when the app is sent to background or terminated on iOS, i.e. on `applicationWillResignActive(_:)` and `applicationWillTerminate(_:)` (both, because the former is not called in certain scenarios, such as a low battery shutdown). Note that multiplexer objects themselves never write data automatically; i.e. the objects are cached only in memory unless you explicitly call `flush()` on a multiplexer, or `flushAll()` on the  global repository.
	static func flushAll() {
		repo.values.forEach { $0.flush() }
	}

	/// Free all memory-cached objects. This will force all multiplexer objects make a new fetch on the next call to `request(completion:)`. This method can be called on memory warnings coming from the OS.
	static func clearMemory() {
		repo.values.forEach { $0.clearMemory() }
	}

	private static var repo: [ObjectIdentifier: MuxRepositoryProtocol] = [:]

	fileprivate static func register(mux: MuxRepositoryProtocol) {
		let id = ObjectIdentifier(mux)
		precondition(repo[id] == nil, "MuxRepository: duplicate registration")
		repo[id] = mux
	}

	fileprivate static func unregister(mux: MuxRepositoryProtocol) {
		let id = ObjectIdentifier(mux)
		repo.removeValue(forKey: id)
	}
}


extension MultiplexerBase {

	/// Register the `Multiplexer<T>` object with the global repository `MuxRepository` for subsequent use in `clearAll()` and `flushAll()` operations. Note that `MuxRepository` retains the object, which means that for non-singleton multiplexer objects `unregister()` should be called prior to freeing it.
	func register() -> Self {
		MuxRepository.register(mux: self)
		return self
	}

	/// Unregister the `Multiplexer<T>` from the global repository `MuxRepository`. Not required for singleton multiplexers.
	func unregister() {
		MuxRepository.unregister(mux: self)
	}
}


extension MultiplexerMapBase {

	/// Register the `MultiplexerMap<T>` object with the global repository `MuxRepository` for subsequent use in `clearAll()` and `flushAll()` operations. Note that `MuxRepository` retains the object, which means that for non-singleton multiplexer objects `unregister()` should be called prior to freeing it.
	func register() -> Self {
		MuxRepository.register(mux: self)
		return self
	}

	/// Unregister the `MultiplexerMap<T>` from the global repository `MuxRepository`. Not required for singleton multiplexers.
	func unregister() {
		MuxRepository.unregister(mux: self)
	}
}
