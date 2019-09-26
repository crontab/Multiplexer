//
//  FileManagerEx.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 25/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation



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

	class func removeCacheDirectory(subDirectory: String) {
		removeRecursively(cacheDirectory(subDirectory: subDirectory, create: false))
	}

	class func removeRecursively(_ url: URL) {
		try? `default`.removeItem(at: url)
	}
}
