//
//  MuxRepository.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 28/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation

#if !NO_UIKIT && os(iOS)
	import UIKit.UIApplication
#endif


public protocol MuxRepositoryProtocol: AnyObject {
	@discardableResult
	func flush() -> Self // store memory cache on disk

	@discardableResult
	func clearMemory() -> Self // free some memory; note that this will force a multiplexer to make a new fetch request next time

	@discardableResult
	func clear() -> Self // clear all memory and disk caches

	var cacheID: String { get }
}


/// Global repository of multiplexers. Multiplexer singletons can be registered here to be included in `clearAll()` and `flushAll()` operations.
public class MuxRepository {

	/// Clears caches for all registered Multiplexer objects. Useful when e.g. the user signs out of the app and there should be no traces left of the previously retrieved backend objects.
	public static func clearAll() {
		repo.values.forEach { $0.clear() }
	}

	/// Writes all memory-cached objects to disk for each of the registered Multiplexer objects. The default implementations of `Multiplexer<T>` and `MultiplexerMap<T>` use simple file-based JSON caching. On iOS MuxRepository can call this method automatically when the app is sent to background if you set `MuxRepository.automaticaFlush` to `true` (presumably at program startup).
	public static func flushAll() {
		repo.values.forEach { $0.flush() }
	}

	/// Free all memory-cached objects. This will force all multiplexer objects make a new fetch on the next call to `request(completion:)`. This method can be called on memory warnings coming from the OS.
	public static func clearMemory() {
		repo.values.forEach { $0.clearMemory() }
	}

	/// If set to `true`, automatically calls `flushAll()` each time the app is sent to background. `flushAll()` ensures only "dirty" objects are written to disk, i.e. those that haven't been written yet.
	public static var automaticFlush: Bool = false {
		didSet {
#if !NO_UIKIT && os(iOS)
			guard oldValue != automaticFlush else { return }
			let center = NotificationCenter.default
			if automaticFlush {
				observer = center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { _ in
					flushAll()
					DLOG("Flushing \(repo.count) registered multiplexers")
				}
			}
			else if let observer {
				center.removeObserver(observer)
			}
#endif
		}
	}

	// - - -

	private static var repo: [String: MuxRepositoryProtocol] = [:]
	private static var observer: NSObjectProtocol?

	fileprivate static func register(mux: MuxRepositoryProtocol) {
		DLOG("Registering multiplexer \(String(describing: mux.self))")
		let id = mux.cacheID
		precondition(repo[id] == nil, "MuxRepository: duplicate registration (ID: \(id))")
		repo[id] = mux
	}

	fileprivate static func unregister(mux: MuxRepositoryProtocol) {
		repo.removeValue(forKey: mux.cacheID)
	}
}


public extension Multiplexer {

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


public extension MultiplexerMap {

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


public extension CachingLoaderBase {

	/// Register the `CachingLoaderBase<T>` object with the global repository `MuxRepository` for subsequent use in `clearAll()`. Flushing has no effect in this case since media files are stored in files anyway.
	@discardableResult
	func register() -> Self {
		MuxRepository.register(mux: self)
		return self
	}

	/// Unregister the `CachingLoaderBase<T>` from the global repository `MuxRepository`. Not required for singleton multiplexers.
	func unregister() {
		MuxRepository.unregister(mux: self)
	}
}
