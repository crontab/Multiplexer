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
		typealias UIImage = NSImage
	#elseif os(iOS)
		import UIKit
	#endif
#endif


#if !NO_UIKIT

/// Asynchronous caching downloader for images. Call `request(url:completion:)` to retrieve the image object or load the cached one. Use the `ImageLoader.main` singleton in your app.
public class ImageLoader: CachingLoaderBase<UIImage> {

	static let main = { ImageLoader() }()

	public override class var cacheFolderName: String { "Images" }

	public override func prepareMemoryObject(cacheFileURL: URL) -> UIImage? {
		return UIImage(contentsOfFile: cacheFileURL.path)
	}
}

#endif


/// Used as a generic type for `CachingVideoLoader<>`. Wraps the URL because CachingLoader<> requires the generic to be a class (and that's because of the NSCache interface)
public class FileURL {
	let fileURL: URL

	init(fileURL: URL) {
		self.fileURL = fileURL
	}
}


/// Asynchronous caching downloader for video, audio or other large media files. Call `request(url:completion:)` or `request(url:progress:completion:)` to retrieve the local file path of the cached object. The result has a type `FileURL` for internal reasons (see comments for FileURL). The media objects themselves are not cached in memory as it is assumed that they will always be streamed from disk. Use the `MediaLoader.main` singleton in your app.
public class MediaLoader: CachingLoaderBase<FileURL> {

	static let main = { MediaLoader() }()

	public override class var cacheFolderName: String { "Videos" }

	public override func prepareMemoryObject(cacheFileURL: URL) -> FileURL? {
		return FileURL(fileURL: cacheFileURL)
	}
}


/// Protocol that defines what should be overridden in subclasses.
public protocol CachingLoaderProtocol {
	associatedtype T: AnyObject

	/// Internal; the last component of the cache path that will be appended to "<cache-folder>/Mux/Files"
	static var cacheFolderName: String { get }

	/// Internal; can return the object, e.g. UIImage, or the file path itself e.g. for media files that will be streamed directly from file, for example video. Return nil if you want to indicate the file is damaged and should be deleted. Otherwise the resulting object will be stored in memory cache.
	func prepareMemoryObject(cacheFileURL: URL) -> T?
}


public let DEFAULT_MEM_CACHE_CAPACITY = 50
let CACHING_LOADER_ERROR_DOMAIN = "MuxCachingLoaderError"


/// Internal class that should be subclassed with CachingLoaderProtocol methods overridden.
public class CachingLoaderBase<T: AnyObject>: CachingLoaderProtocol, MuxRepositoryProtocol {
	public typealias OnResult = (Result<T, Error>) -> Void

	/// Instantiates a CachingLoader object with the memory capacity parameter. Internal.
	public init(memoryCacheCapacity: Int = DEFAULT_MEM_CACHE_CAPACITY) {
		memCache = CachingDictionary(capacity: memoryCacheCapacity)
	}


	///
	/// Retrieves a media object from the given URL. When called for the first time, this method initiates an actual download; subsequent (or parallel) calls will return the cached object. Up to a certain number of objects can be kept in memory for faster access. Soft refresh is not supported by this interface as it is assumed media objects are immutable, i.e. once downloaded from a given URL the object can be kept locally indefinitely.
	/// - parameter url: remote (non-file) URL of the media object to be retrieved.
	/// - parameter progress: on optional callback to report downloading progress to the user; provides the number of bytes received and the total number of bytes to be downloaded in regular intervals
	/// - parameter completion: user's callback function for receiving the result as `Result<T, Error>`
	///

	public func request(url: URL, progress: ((Int64, Int64) -> Void)?, completion: @escaping OnResult) {
		// Available in the cache? Return immediately:
		if let object = memCache[url.absoluteString as NSString] {
			completion(.success(object))
			return
		}

		// Queue requests to be called later at once, when the result becomes available; the first request triggers the download:
		if var completionQueue = completions[url], !completionQueue.isEmpty {
			completionQueue.append(completion)
		}
		else {
			completions[url] = [completion]
			fetch(url: url, progress: progress)
		}
	}


	///
	/// Convenience alias to `request(url:progress:completion:)`. Retrieves a media object from the given URL. When called for the first time, this method initiates an actual download; subsequent (or parallel) calls will return the cached object. There is no expiration in this case unlike the Multiplexer family of interfaces. Up to a certain number of objects can be kept in memory for faster access. Soft refresh is not supported by this interface as it is assumed media objects are immutable, i.e. once downloaded from a given URL the object can be kept locally indefinitely.
	/// - parameter url: remote (non-file) URL of the media object to be retrieved.
	/// - parameter completion: user's callback function for receiving the result as `Result<T, Error>`
	///

	public func request(url: URL, completion: @escaping OnResult) {
		request(url: url, progress: nil, completion: completion)
	}


	/// Can be called to check whether a given object is available locally or it will be downloaded on next call to `request(...)`
	public func willRefresh(url: URL) -> Bool {
		return memCache[url.absoluteString as NSString] == nil || !FileManager.exists(cacheFileURLFor(url: url, create: false))
	}


	/// Discard the objects stored in the memory cache
	@discardableResult
	public func clearMemory() -> Self {
		memCache.clear()
		return self
	}


	/// Discard the disk cache for this class of objects (i.e. images in case of the ImageLoader)
	@discardableResult
	public func clearCache() -> Self {
		// NOTE: clearCache() should never be called from within a completion handler (I don't remember why, but believe me it's bad)
		FileManager.removeRecursively(cacheSubdirectory(create: false))
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


	public class var cacheFolderName: String {
		preconditionFailure()
	}


	public func prepareMemoryObject(cacheFileURL: URL) -> T? {
		preconditionFailure()
	}


	private func fetch(url: URL, progress: ((Int64, Int64) -> Void)?) {
		let cacheFileURL = cacheFileURLFor(url: url, create: true)

		// Cache file exists? Resolve the queue immediately.
		if FileManager.exists(cacheFileURL) {
			// print("CachingLoader: mem cache miss, loading from disk: \(cacheFileURL.lastPathComponent)")
			fetchCompleted(url: url, result: .success(cacheFileURL))
		}

		// Otherwise start the download:
		else {
			// print("CachingLoader: Downloading: \(key)")
			FileDownloader(url: url, progress: progress, completion: { (result) in
				switch result {
				case .failure(let error):
					self.fetchCompleted(url: url, result: .failure(error))
				case .success(let tempURL):
					try! FileManager.default.moveItem(at: tempURL, to: cacheFileURL)
					self.fetchCompleted(url: url, result: .success(cacheFileURL))
				}
			}).resume()
		}
	}


	private func fetchCompleted(url: URL, result: Result<URL, Error>) {
		switch result {

		case .failure(let error):
			complete(url: url, result: .failure(error))

		case .success(let cacheFileURL):
			// Refresh ended successfully: allow the subclass to load the data (or do whatever transformation) that should be stored in the memory cache:
			if let object = prepareMemoryObject(cacheFileURL: cacheFileURL) {
				memCache[url.absoluteString as NSString] = object
				complete(url: url, result: .success(object))
			}

			// The subclass transformation function returned nil: delete the file and signal an app error:
			else {
				memCache[url.absoluteString as NSString] = nil
				FileManager.removeRecursively(cacheFileURL)
				complete(url: url, result: .failure(NSError(domain: CACHING_LOADER_ERROR_DOMAIN, code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load cache file from disk"])))
			}
		}
	}


	private func complete(url: URL, result: Result<T, Error>) {
		while let completionQueue = completions[url], !completionQueue.isEmpty {
			completions[url]!.removeFirst()(result)
		}
		completions.removeValue(forKey: url)
	}


	private var memCache: CachingDictionary<NSString, T>

	private var completions: [URL: [OnResult]] = [:]

	private func cacheFileURLFor(url: URL, create: Bool) -> URL {
		return cacheSubdirectory(create: create).appendingPathComponent(url.absoluteString.toURLSafeHash(max: 32)).appendingPathExtension(url.pathExtension)
	}

	private func cacheSubdirectory(create: Bool) -> URL {
		return FileManager.cacheDirectory(subDirectory: "Mux/" + Self.cacheFolderName, create: create)
	}
}


/// Internal wrapper for the NSCache interface. NSCache is good but it's also thread-safe which is not required here. Might be replaced with something else in the future.
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
