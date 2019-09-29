//
//  Cacher.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 27/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


public protocol Cacher {
	associatedtype T: Codable
	typealias K = String

	static func loadFromCache<T: Codable>(key: K, domain: String?) -> T?
	static func saveToCache<T: Codable>(_ result: T, key: K, domain: String?)
	static func clearCache(key: K, domain: String?)
	static func clearCacheMap(domain: String)
}


public final class NoCacher<T: Codable>: Cacher {
	public static func loadFromCache<T: Codable>(key: K, domain: String?) -> T? { nil }
	public static func saveToCache<T: Codable>(_ result: T, key: K, domain: String?) { }
	public static func clearCache(key: K, domain: String?) { }
	public static func clearCacheMap(domain: String) { }
}


private let jsonDecoder: JSONDecoder = { JSONDecoder() }()
private let jsonEncoder: JSONEncoder = { JSONEncoder() }()


public final class JSONDiskCacher<T: Codable>: Cacher {

	public static func loadFromCache<T: Codable>(key: K, domain: String?) -> T? {
		return try? jsonDecoder.decode(T.self, from: Data(contentsOf: cacheFileURL(key: key, domain: domain, create: false)))
	}

	public static func saveToCache<T: Codable>(_ result: T, key: K, domain: String?) {
		try! jsonEncoder.encode(result).write(to: cacheFileURL(key: key, domain: domain, create: true), options: .atomic)
	}

	public static func clearCache(key: K, domain: String?) {
		FileManager.removeRecursively(cacheFileURL(key: key, domain: domain, create: false))
	}

	public static func clearCacheMap(domain: String) {
		FileManager.removeRecursively(cacheDirURL(domain: domain, create: false))
	}

	private static func cacheFileURL(key: K, domain: String?, create: Bool) -> URL {
		return cacheDirURL(domain: domain, create: create).appendingPathComponent(key.description).appendingPathExtension("json")
	}

	private static func cacheDirURL(domain: String?, create: Bool) -> URL {
		let dir = "Mux/" + (domain != nil ? domain! + ".Map" : "")
		return FileManager.cacheDirectory(subDirectory: dir, create: create)
	}
}
