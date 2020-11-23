//
//  FileManagerEx.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 28/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


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

	static func removeRecursively(_ url: URL?) {
		if let url = url {
			try? `default`.removeItem(at: url)
		}
	}

	static func exists(_ url: URL) -> Bool {
		return url.isFileURL && `default`.fileExists(atPath: url.path)
	}
}
