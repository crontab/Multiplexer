//
//  Cacher.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 27/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


public typealias MuxKey = LosslessStringConvertible & Hashable


public protocol Cacher {
	associatedtype T: Codable
	associatedtype K: MuxKey

	static func loadFromCache<K: MuxKey, T: Codable>(key: K, domain: String?) -> T?
	static func saveToCache<K: MuxKey, T: Codable>(_ result: T, key: K, domain: String?)
	static func clearCache<K: MuxKey>(key: K, domain: String?)
	static func clearCacheMap(domain: String)
}


public final class NoCacher<K: MuxKey, T: Codable>: Cacher {
	public static func loadFromCache<K: MuxKey, T: Codable>(key: K, domain: String?) -> T? { nil }
	public static func saveToCache<K: MuxKey, T: Codable>(_ result: T, key: K, domain: String?) { }
	public static func clearCache<K: MuxKey>(key: K, domain: String?) { }
	public static func clearCacheMap(domain: String) { }
}


private let jsonDecoder: JSONDecoder = { JSONDecoder() }()
private let jsonEncoder: JSONEncoder = { JSONEncoder() }()


public final class JSONDiskCacher<K: MuxKey, T: Codable>: Cacher {

	public static func loadFromCache<K: MuxKey, T: Codable>(key: K, domain: String?) -> T? {
		return try? jsonDecoder.decode(T.self, from: Data(contentsOf: cacheFileURL(key: key, domain: domain, create: false)))
	}

	public static func saveToCache<K: MuxKey, T: Codable>(_ result: T, key: K, domain: String?) {
		try! jsonEncoder.encode(result).write(to: cacheFileURL(key: key, domain: domain, create: true), options: .atomic)
	}

	public static func clearCache<K: MuxKey>(key: K, domain: String?) {
		FileManager.remove(cacheFileURL(key: key, domain: domain, create: false))
	}

	public static func clearCacheMap(domain: String) {
		FileManager.remove(cacheDirURL(domain: domain, create: false))
	}

	private static func cacheFileURL<K: MuxKey>(key: K, domain: String?, create: Bool) -> URL {
		return cacheDirURL(domain: domain, create: create).appendingPathComponent(key.description).appendingPathExtension("json")
	}

	private static func cacheDirURL(domain: String?, create: Bool) -> URL {
		let dir = "Mux/" + (domain != nil ? domain! + ".Map" : "")
		return FileManager.cachesDirectory(subDirectory: dir, create: create)
	}
}
