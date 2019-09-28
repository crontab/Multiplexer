//
//  CachingLoader.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 07/05/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


typealias CachingLoader<T: AnyObject> = CachingLoaderImpl<T> & CachingLoaderProtocol


struct CachingDictionary<K: AnyObject, T: AnyObject> {

	private var cache = NSCache<K, T>()

	init(capacity: Int) {
		cache.countLimit = capacity
	}

	subscript(key: K) -> T? {
		get {
			return cache.object(forKey: key)
		}
		set {
			if newValue == nil {
				cache.removeObject(forKey: key)
			}
			else {
				cache.setObject(newValue!, forKey: key)
			}
		}
	}

	func clear() {
		cache.removeAllObjects()
	}
}



let DEFAULT_MEM_CACHE_CAPACITY = 50
let CACHING_LOADER_ERROR_DOMAIN = "MuxCachingLoaderError"


protocol CachingLoaderProtocol {
	var cacheFolderName: String { get }

	// Can return the object, e.g. UIImage, or the file path itself e.g. for media files that will be streamed directly from file. The reason the return type is not a generic is because Swift is still bad at overriding protocol generics in classes. Return nil if you want to indicate the file is damaged and should be deleted.
	func readFromCacheFile(path: String) -> Any?
}


class CachingLoaderImpl<T: AnyObject> {
	typealias OnResult = (Result<T, Error>) -> Void

	private var memCache: CachingDictionary<NSString, T>
	private var completions: [URL: [OnResult]] = [:]


	init(memoryCacheCapacity: Int = DEFAULT_MEM_CACHE_CAPACITY) {
		memCache = CachingDictionary(capacity: memoryCacheCapacity)
	}


	func request(url: URL, completion: @escaping OnResult, progress: ((Int64, Int64) -> Void)? = nil) {
		// Available in the cache? Return immediately:
		if let object = memCache[url.absoluteString as NSString] {
			completion(.success(object))
			return
		}

		// Queue requests to be called later at once, when the result becomes available; the first request triggers the download:
		if completions[url] == nil || completions[url]!.isEmpty {
			completions[url] = [completion]
			refresh(url: url, progress: progress)
		}
		else {
			completions[url]!.append(completion)
		}
	}


	func willRefresh(url key: String) -> Bool {
		if memCache[key as NSString] != nil {
			return false
		}
		guard let url = URL(string: key) else {
			return false
		}
		return FileManager.exists(cacheFileURLFor(url: url))
	}


	// - - - PROTECTED

	private func refresh(url: URL, progress: ((Int64, Int64) -> Void)?) {
		// TODO: handle the file:/// scheme

		let cacheFileURL = cacheFileURLFor(url: url)

		// Cache file exists? Resolve the queue immediately (currently only one deferred request will be in the queue in this case, but in the future we might support some more asynchronicity in how the file is loaded):
		if FileManager.exists(cacheFileURL) {
			// print("CachingLoader: mem cache miss, loading from disk: \(cacheFileURL.lastPathComponent)")
			refreshCompleted(url: url, cacheFileURL: cacheFileURL, error: nil)
		}

		// Otherwise start the async download:
		else {
			// print("CachingLoader: Downloading: \(key)")
			FileDownloader(url: url, progress: progress, completion: { (tempURL, error) in
				if let error = error {
					self.refreshCompleted(url: url, cacheFileURL: nil, error: error)
				}
				else if let tempURL = tempURL {
					try! FileManager.default.moveItem(at: tempURL, to: cacheFileURL)
					self.refreshCompleted(url: url, cacheFileURL: cacheFileURL, error: nil)
				}
				else {
					preconditionFailure()
				}
			}).resume()
		}
	}


	private func refreshCompleted(url: URL, cacheFileURL: URL?, error: Error?) {
		// Resolve the queue: call completion handlers accumulated so far:
		while completions[url] != nil && !completions[url]!.isEmpty {
			let completion = completions[url]!.removeFirst()
			if let cacheFileURL = cacheFileURL {
				refreshCompleted(url: url, cacheFileURL: cacheFileURL, completion: completion)
			}
			else if let error = error {
				completion(.failure(error))
			}
			else {
				preconditionFailure()
			}
		}
		completions.removeValue(forKey: url)
	}


	private func refreshCompleted(url: URL, cacheFileURL: URL, completion: @escaping OnResult) {
		// Refresh ended successfully: allow the subclass to load the data (or do whatever transformation) that should be stored in the memory cache:
		if let result = (self as! CachingLoaderProtocol).readFromCacheFile(path: cacheFileURL.path) {
			memCache[url.absoluteString as NSString] = (result as! T)
			completion(.success(result as! T))
		}

		// The subclass transformation function returned nil: delete the file and signal an app error:
		else {
			FileManager.removeRecursively(cacheFileURL)
			completion(.failure(NSError(domain: CACHING_LOADER_ERROR_DOMAIN, code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load cache file from disk"])))
		}
	}


	func cacheFileURLFor(url: URL) -> URL {
		return cacheSubdirectory(create: true).appendingPathComponent(url.absoluteString.toURLSafeHash(max: 32)).appendingPathExtension(url.pathExtension)
	}


	func cacheSubdirectory(create: Bool) -> URL {
		return FileManager.cacheDirectory(subDirectory: (self as! CachingLoaderProtocol).cacheFolderName, create: create)
	}


	func clearMemory() {
		memCache.clear()
	}


	func clearCache() {
		// NOTE: clearCache() should never be called from within a completion handler
		FileManager.removeRecursively(cacheSubdirectory(create: false))
	}


	func clear() {
		clearCache()
		clearMemory()
	}
}

