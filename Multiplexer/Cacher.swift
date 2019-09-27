//
//  Cacher.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 27/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


let STANDARD_TTL: TimeInterval = 30 * 60

internal let jsonDecoder: JSONDecoder = { JSONDecoder() }()
internal let jsonEncoder: JSONEncoder = { JSONEncoder() }()


protocol Cacher {
	associatedtype T: Codable
	typealias K = String

	static func useCachedResultOn(error: Error) -> Bool
	static var timeToLive: TimeInterval { get }
	static var cacheDomain: String { get }

	static func loadFromCache<T: Codable>() -> T?
	static func saveToCache<T: Codable>(_ result: T)
	static func clearCache()

	static func loadFromCache<T: Codable>(key: K) -> T?
	static func saveToCache<T: Codable>(_ result: T, key: K)
	static func clearCache(key: K)
	static func clearCacheMap()
}


final class NoCacher<T: Codable>: Cacher {
	static func useCachedResultOn(error: Error) -> Bool { false }
	static var timeToLive: TimeInterval { 0 }
	static var cacheDomain: String { String(describing: T.self) }

	static func loadFromCache<T: Codable>() -> T? { nil }
	static func saveToCache<T: Codable>(_ result: T) { }
	static func clearCache() { }

	static func loadFromCache<T: Codable>(key: K) -> T? { nil }
	static func saveToCache<T: Codable>(_ result: T, key: K) { }
	static func clearCache(key: K) { }
	static func clearCacheMap() { }
}


extension FileManager {

	class func cacheDirectory(subDirectory: String, create: Bool) -> URL {
		guard let result = `default`.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(subDirectory) else {
			preconditionFailure("No cache directory")
		}
		if create && !`default`.fileExists(atPath: result.path) {
			do {
				try `default`.createDirectory(at: result, withIntermediateDirectories: true, attributes: nil)
			}
			catch {
				preconditionFailure("Couldn't create cache directory (\(result))")
			}
		}
		return result
	}

	class func removeRecursively(_ url: URL?) {
		if let url = url {
			try? `default`.removeItem(at: url)
		}
	}
}


final class JSONDiskCacher<T: Codable>: Cacher {

	static func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }

	static var timeToLive: TimeInterval { STANDARD_TTL }

	static var cacheDomain: String { String(describing: T.self) }

	static func loadFromCache<T: Codable>() -> T? {
		return try? jsonDecoder.decode(T.self, from: Data(contentsOf: cacheFileURL(create: false)))
	}

	static func saveToCache<T: Codable>(_ result: T) {
		try! jsonEncoder.encode(result).write(to: cacheFileURL(create: true), options: .atomic)
	}

	static func clearCache() {
		FileManager.removeRecursively(cacheFileURL(create: false))
	}

	static func cacheFileURL(create: Bool) -> URL {
		return FileManager.cacheDirectory(subDirectory: "Mux/", create: create).appendingPathComponent(cacheDomain).appendingPathExtension("json")
	}

	static func loadFromCache<T: Codable>(key: K) -> T? {
		return try? jsonDecoder.decode(T.self, from: Data(contentsOf: cacheFileURL(key: key, create: false)))
	}

	static func saveToCache<T: Codable>(_ result: T, key: K) {
		try! jsonEncoder.encode(result).write(to: cacheFileURL(key: key, create: true), options: .atomic)
	}

	static func clearCache(key: K) {
		FileManager.removeRecursively(cacheFileURL(key: key, create: false))
	}

	static func clearCacheMap() {
		FileManager.removeRecursively(cacheDirURL(create: false))
	}

	static func cacheFileURL(key: K, create: Bool) -> URL {
		return cacheDirURL(create: create).appendingPathComponent(key.description).appendingPathExtension("json")
	}

	static func cacheDirURL(create: Bool) -> URL {
		return FileManager.cacheDirectory(subDirectory: "Mux/" + cacheDomain + ".Map", create: create)
	}
}
