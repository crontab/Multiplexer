//
//  FileManagerEx.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 28/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


extension FileManager {

	class func cacheDirectory(subDirectory: String, create: Bool) -> URL {
		let result = `default`.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(subDirectory)
		if create && !`default`.fileExists(atPath: result.path) {
			try! `default`.createDirectory(at: result, withIntermediateDirectories: true, attributes: nil)
		}
		return result
	}

	class func removeRecursively(_ url: URL?) {
		if let url = url {
			try? `default`.removeItem(at: url)
		}
	}

	class func exists(_ url: URL) -> Bool {
		return url.isFileURL && `default`.fileExists(atPath: url.path)
	}
}
