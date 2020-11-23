//
//  FileManagerEx.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 28/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


/// File manager shortcuts
public extension FileManager {

	static func cachesDirectory(subDirectory: String, create: Bool = false) -> URL {
		standardDirectory(.cachesDirectory, subDirectory: subDirectory, create: create)
	}

	static func documentDirectory(subDirectory: String, create: Bool = false) -> URL {
		standardDirectory(.documentDirectory, subDirectory: subDirectory, create: create)
	}

	private static func standardDirectory(_ type: SearchPathDirectory, subDirectory: String, create: Bool = false) -> URL {
		let result = `default`.urls(for: type, in: .userDomainMask).first!.appendingPathComponent(subDirectory)
		if create && !`default`.fileExists(atPath: result.path) {
			try! `default`.createDirectory(at: result, withIntermediateDirectories: true, attributes: nil)
		}
		return result
	}

	static func exists(_ url: URL) -> Bool {
		url.isFileURL && `default`.fileExists(atPath: url.path)
	}

	static func move(from: URL, to: URL) -> Bool {
		do {
			try `default`.moveItem(at: from, to: to)
		}
		catch {
			return false
		}
		return true
	}

	static func isDirectory(_ url: URL) -> Bool {
		guard url.isFileURL else { return false }
		var isDir: ObjCBool = false
		let result = `default`.fileExists(atPath: url.path, isDirectory: &isDir)
		return result && isDir.boolValue
	}

	static func list(_ dir: URL) -> [URL] {
		(try? `default`.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])) ?? []
	}

	static func remove(_ url: URL) {
		try? `default`.removeItem(at: url)
	}
}
