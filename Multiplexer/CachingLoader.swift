//
//  CachingLoader.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 07/05/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


// The below is for UIImage. You can exclude ImageLoader and UIKit linkage by specifying the NO_UIKIT conditional.

#if !NO_UIKIT
	#if os(OSX)
		import Cocoa
		public typealias UIImage = NSImage
	#elseif os(iOS)
		import UIKit
	#endif
#endif


#if !NO_UIKIT

/// Asynchronous caching downloader for images. Call `request(url:completion:)` to retrieve the image object or load the cached one. Use the `ImageLoader.main` singleton in your app.
public class ImageLoader: CachingLoaderBase<UIImage> {

	public static let main = { ImageLoader() }()

	public override var cacheID: String { "Images" }

	private static let ioQueue = DispatchQueue(label: "com.melikyan.CachingImageLoader", qos: .background)

	public override func prepareMemoryObject(cacheFileURL: URL, completion: @escaping (UIImage?) -> Void) {
		Self.ioQueue.async {
			let image = UIImage(contentsOfFile: cacheFileURL.path)
			if let image = image {
				// Make sure the image is decompressed on the background thread
				UIGraphicsBeginImageContext(image.size)
				image.draw(at: .zero)
				UIGraphicsEndImageContext()
			}
			Async {
				completion(image)
			}
		}
	}
}

#endif


/// Asynchronous caching downloader for video, audio or other large media files. Call `request(url:completion:)` or `request(url:progress:completion:)` to retrieve the local file path of the cached object. The result is a file URL. The media objects themselves are not cached in memory as it is assumed that they will always be streamed from disk. Use the `MediaLoader.main` singleton in your app.
public class MediaLoader: CachingLoaderBase<URL> {

	public static let main = { MediaLoader() }()

	public override var cacheID: String { "Media" }

	public override func prepareMemoryObject(cacheFileURL: URL, completion: @escaping (URL?) -> Void) {
		completion(cacheFileURL)
	}
}


/// Protocol that defines what should be overridden in subclasses.
public protocol CachingLoaderProtocol {
	associatedtype T

	/// Internal; can return the object, e.g. UIImage, or the file path itself e.g. for media files that will be streamed directly from file, for example video. Return nil if you want to indicate the file is damaged and should be deleted. Otherwise the resulting object will be stored in memory cache.
	func prepareMemoryObject(cacheFileURL: URL, completion: @escaping (T?) -> Void)
}


public let DEFAULT_MEM_CACHE_CAPACITY = 50
let CACHING_LOADER_ERROR_DOMAIN = "MuxCachingLoaderError"


/// Internal class that should be subclassed with CachingLoaderProtocol methods overridden.
public class CachingLoaderBase<T>: CachingLoaderProtocol, MuxRepositoryProtocol {
	public typealias OnResult = (Result<T, Error>) -> Void

	/// Instantiates a CachingLoader object with the memory capacity parameter. Internal.
	public init(memoryCacheCapacity: Int = DEFAULT_MEM_CACHE_CAPACITY) {
		memCache = LRUCache(capacity: memoryCacheCapacity)
	}


	///
	/// Retrieves a media object from a given URL. When called for the first time, this method initiates an actual download; subsequent (or parallel) calls will return the cached object. Up to a certain number of objects can be kept in memory for faster access. Soft refresh is not supported by this interface as it is assumed media objects are immutable, i.e. once downloaded from a given URL the object can be kept locally indefinitely.
	/// - parameter url: remote (non-file) URL of the media object to be retrieved.
	/// - parameter progress: on optional callback to report downloading progress to the user; provides the number of bytes received and the total number of bytes to be downloaded in regular intervals
	/// - parameter completion: user's callback function for receiving the result as `Result<T, Error>`. If `completion` is nil, the object is downloaded (if required) but not expanded in memory; this can be useful for e.g. prefetching images without uncompressing them at program startup.
	///

	public func request(url: URL, progress: ((Int64, Int64) -> Void)?, completion: OnResult?) {
		// Available in the cache? Return immediately:
		if let object = memCache.touch(key: url.absoluteString) {
			completion?(.success(object))
			return
		}

		// File URL, i.e. it's a local file, no need to queue or download
		if url.isFileURL {
			if let completion = completion {
				prepareMemoryObject(cacheFileURL: url) { (result) in
					if let object = result {
						self.memCache.set(object, forKey: url.absoluteString)
						completion(.success(object))
					}
					else {
						completion(.failure(NSError(domain: CACHING_LOADER_ERROR_DOMAIN, code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load file from disk"])))
					}
				}
			}
			return
		}

		// Queue requests to be called later at once, when the result becomes available; the first request triggers the download:
		if completions[url] == nil {
			completions[url] = [completion]
			fetch(url: url, progress: progress)
		}
		else {
			completions[url]!.append(completion)
		}
	}


	///
	/// Convenience alias to `request(url:progress:completion:)`. Retrieves a media object from a given URL. When called for the first time, this method initiates an actual download; subsequent (or parallel) calls will return the cached object. There is no expiration in this case unlike the Multiplexer family of interfaces. Up to a certain number of objects can be kept in memory for faster access. Soft refresh is not supported by this interface as it is assumed media objects are immutable, i.e. once downloaded from a given URL the object can be kept locally indefinitely.
	/// - parameter url: remote (non-file) URL of the media object to be retrieved.
	/// - parameter completion: user's callback function for receiving the result as `Result<T, Error>`. If `completion` is nil, the object is downloaded (if required) but not expanded in memory; this can be useful for e.g. prefetching images without uncompressing them at program startup.
	///

	public func request(url: URL, completion: OnResult?) {
		request(url: url, progress: nil, completion: completion)
	}


	/// Can be called to check whether a given object is available locally or it will be downloaded on next call to `request(...)`
	public func willRefresh(url: URL) -> Bool {
		if memCache.has(key: url.absoluteString) {
			return false
		}
		if url.isFileURL {
			return false
		}
		return !FileManager.exists(cacheFileURLFor(url: url, create: false))
	}


	/// Discard the objects stored in the memory cache
	@discardableResult
	public func clearMemory() -> Self {
		memCache.removeAll()
		return self
	}


	/// Discard the disk cache for this class of objects (i.e. images in case of the ImageLoader)
	@discardableResult
	public func clearCache() -> Self {
		// NOTE: clearCache() should never be called from within a completion handler (I don't remember why, but believe me it's bad)
		FileManager.remove(cacheSubdirectory(create: false))
		return self
	}


	/// Clear both memory and disk caches
	@discardableResult
	public func clear() -> Self {
		clearCache()
		return clearMemory()
	}


	@discardableResult
	public func flush() -> Self {
		return self
	}


	public var cacheID: String {
		preconditionFailure()
	}


	public func prepareMemoryObject(cacheFileURL: URL, completion: @escaping (T?) -> Void) {
		preconditionFailure()
	}


	private func fetch(url: URL, progress: ((Int64, Int64) -> Void)?) {
		let cacheFileURL = cacheFileURLFor(url: url, create: true)

		// Cache file exists? Resolve the queue immediately.
		if FileManager.exists(cacheFileURL) {
			DLOG("CachingLoader: mem cache miss, found on disk: \(cacheFileURL.lastPathComponent)")
			fetchCompleted(url: url, result: .success(cacheFileURL))
		}

		// Otherwise start the download:
		else {
			DLOG("CachingLoader: Downloading: \(url.absoluteString)")
			FileDownloader(url: url, progress: progress, completion: { (result) in
				switch result {
				case .failure(let error):
					self.fetchCompleted(url: url, result: .failure(error))
				case .success(let tempURL):
					do {
						try FileManager.default.moveItem(at: tempURL, to: cacheFileURL)
						self.fetchCompleted(url: url, result: .success(cacheFileURL))
					}
					catch {
						self.fetchCompleted(url: url, result: .failure(NSError(domain: CACHING_LOADER_ERROR_DOMAIN, code: 2, userInfo: [NSLocalizedDescriptionKey: "File download failed"])))
					}
				}
			}).resume()
		}
	}


	private func fetchCompleted(url: URL, result: Result<URL, Error>) {
		switch result {

		case .failure(let error):
			complete(url: url, result: .failure(error))

		case .success(let cacheFileURL):
			// Refresh ended successfully: allow the subclass to load the data (or do whatever transformation) that should be stored in the memory cache. Before that, check if all completion blocks are empty, i.e. no need to transform the object.
			// Note that this will not load the object into the mem cache. If you want it to be loaded, call `request()` with a non-nil completion handler.

			if completions[url]?.firstIndex(where: { $0 != nil }) == nil {
				completions.removeValue(forKey: url)
				return
			}

			prepareMemoryObject(cacheFileURL: cacheFileURL) { (result) in
				if let object = result {
					self.memCache.set(object, forKey: url.absoluteString)
					self.complete(url: url, result: .success(object))
				}
				else {
					// The subclass transformation function returned nil: delete the file and signal an app error:
					self.memCache.remove(key: url.absoluteString)
					FileManager.remove(cacheFileURL)
					self.complete(url: url, result: .failure(NSError(domain: CACHING_LOADER_ERROR_DOMAIN, code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load cache file from disk"])))
				}
			}
		}
	}


	private func complete(url: URL, result: Result<T, Error>) {
		while !(completions[url]?.isEmpty ?? true) {
			completions[url]!.removeFirst()?(result)
		}
		completions.removeValue(forKey: url)
	}


	private var memCache: LRUCache<String, T>

	private var completions: [URL: [OnResult?]] = [:]

	private func cacheFileURLFor(url: URL, create: Bool) -> URL {
		return cacheSubdirectory(create: create).appendingPathComponent(url.absoluteString.toURLSafeHash(max: 32)).appendingPathExtension(url.pathExtension)
	}

	private func cacheSubdirectory(create: Bool) -> URL {
		return FileManager.cachesDirectory(subDirectory: "Mux/" + cacheID, create: create)
	}
}
