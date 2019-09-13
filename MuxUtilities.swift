//
//  MuxUtilities.swift
//
//  Created by Hovik Melikyan on 14/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


// Defer execution of blocks until an object becomes available (e.g. the app's root view controller)

class MuxWeakAvailability<T: AnyObject> {
	typealias Block = (_ object: T) -> Void

	private var blocks: [Block] = []

	weak var object: T? = nil {
		didSet {
			while object != nil && !blocks.isEmpty {
				blocks.removeFirst()(object!)
			}
		}
	}

	func execute(block: @escaping Block) {
		if let object = object {
			block(object)
		}
		else {
			blocks.append(block)
		}
	}
}



// Update a value and execute a block with some delay. Each time the value is updated, the execution is deferred even more, i.e. there has to be "silence" for a certain period of time for the block to be executed. Useful for e.g. live search scenarios when a network request needs to be executed only when there is no user input for e.g. 1 second.

class MuxUpdater<T> where T: Equatable {

	init(delay: TimeInterval, initialValue: T) {
		self.delay = delay
		self.value = initialValue
	}

	func update(newValue: T, executeWithDelay: @escaping (_ value: T) -> Void) {
		guard newValue != value else {
			return
		}
		value = newValue
		if workItem == nil {
			workItem = DispatchWorkItem(block: {
				executeWithDelay(self.value)
				self.workItem = nil
			})
			DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
		}
	}

	func cancel() {
		workItem?.cancel()
		workItem = nil
	}

	private var value: T
	private var delay: TimeInterval
	private var workItem: DispatchWorkItem?
}



// Execute a list blocks, each of which can return some asynchronous result or an error; call the final completion block when all the blocks are done. If any of the blocks result in errors, then the last error object is returned to the final completion block. Useful for making parallel network request that make sense only when all of them finish with some result.

func MuxMultiRequester(_ blocks: [(@escaping (Any?, Error?) -> Void) -> Void], completion: @escaping ([Any?], Error?) -> Void) {
	var resultCount = 0
	var results = Array<Any?>(repeating: nil, count: blocks.count)
	var resultError: Error? = nil

	guard !blocks.isEmpty else {
		completion(results, resultError)
		return
	}
	for i in blocks.indices {
		blocks[i]({ (result, error) in
			if let error = error {
				resultError = error
			}
			results[i] = result
			resultCount += 1
			if resultCount == blocks.count {
				completion(results, error)
			}
		})
	}
}



// Execute an asynchronous operation (e.g. a backend request) once, then call completion handlers for multiple waiting blocks. This simple paradigm allows to make one network request and return results to potentially multiple callers who are interested in the same thing.

class MuxRequester<T> {
	typealias Completion = (T?, Error?) -> Void

	private var completions: [Completion] = []

	func execute(completion: @escaping Completion, executeOnce: (@escaping Completion) -> Void) {
		completions.append(completion)
		if completions.count == 1 {
			executeOnce { (result, error) in
				while !self.completions.isEmpty {
					self.completions.removeFirst()(result, error)
				}
			}
		}
	}
}



// Extending MuxRequester, MuxCachingRequester caches the result for the next TTL seconds. Disk caching can be used as well if `cacheFileName` is overridden in a subclass. The objects are stored on disk in JSON format, hence the requirement that the generic type is Codable.

private let STANDARD_TTL: TimeInterval = 30 * 60

class MuxCachingRequester<T: Codable>: MuxRequester<T> {

	private var completionTime: TimeInterval?
	private var previousResult: T?

	override func execute(completion: @escaping Completion, executeOnce: (@escaping Completion) -> Void) {
		if resultAvailable {
			completion(previousResult, nil)
			return
		}
		super.execute(completion: completion) { (completion) in
			executeOnce { (result, error) in
				var newResult = result
				var newError = error
				self.completionTime = newError == nil ? Date().timeIntervalSinceReferenceDate : nil
				if let error = newError, self.useCachedResultOn(error: error) {
					newResult = self.previousResult ?? self.loadFromCache()
					if newResult != nil {
						newError = nil
					}
				}
				else if let newResult = newResult {
					self.saveToCache(newResult)
				}
				self.previousResult = newResult
				completion(newResult, newError)
			}
		}
	}

	func useCachedResultOn(error: Error) -> Bool {
		if (error as NSError).domain == NSURLErrorDomain {
			return [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost].contains((error as NSError).code)
		}
		return false
	}

	var timeToLive: TimeInterval {
		return STANDARD_TTL
	}

	func loadFromCache() -> T? {
		if let cacheFileURL = cacheFileURL(create: false) {
			return try? jsonDecoder.decode(T.self, from: Data(contentsOf: cacheFileURL))
		}
		return nil
	}

	func saveToCache(_ result: T) {
		if let cacheFileURL = cacheFileURL(create: true) {
			try! jsonEncoder.encode(result).write(to: cacheFileURL, options: .atomic)
		}
	}

	func clear() {
		clearMemory()
		if let cacheFileURL = cacheFileURL(create: false) {
			FileManager.removeRecursively(cacheFileURL.path)
		}
	}

	func clearMemory() {
		completionTime = nil
		previousResult = nil
	}

	private var resultAvailable: Bool {
		guard let completionTime = completionTime else {
			return false
		}
		return Date().timeIntervalSinceReferenceDate <= completionTime + timeToLive
	}

	fileprivate func cacheFileURL(create: Bool) -> URL? {
		if let cacheFileName = cacheFileName {
			return URL(fileURLWithPath: FileManager.cacheDirectory(subDirectory: "Mux", create: create)).appendingPathComponent(cacheFileName)
		}
		return nil
	}

	var cacheFileName: String? {
		return nil
	}
}



// A map of MuxCachingRequester objects; useful for caching network objects that have an ID, e.g. user profiles.

class MuxCachingRequesterMap<T: Codable> {

	typealias K = String
	typealias Completion = (T?, Error?) -> Void

	private class Requester: MuxCachingRequester<T> {
		private var key: K
		private weak var dict: MuxCachingRequesterMap<T>?

		init(key: K, dict: MuxCachingRequesterMap) {
			self.key = key
			self.dict = dict
		}

		override func cacheFileURL(create: Bool) -> URL? {
			if let cacheSubdirectoryName = dict?.cacheSubdirectoryName {
				return URL(fileURLWithPath: FileManager.cacheDirectory(subDirectory: "Mux/" + cacheSubdirectoryName, create: create)).appendingPathComponent(key.isEmpty ? ".default" : key)
			}
			return nil
		}
	}

	private var dict: [K: Requester] = [:]

	func execute(key: K, completion: @escaping Completion, executeOnce: (@escaping Completion) -> Void) {
		var requester: Requester! = dict[key]
		if requester == nil {
			requester = Requester(key: key, dict: self)
			dict[key] = requester
		}
		requester.execute(completion: completion, executeOnce: executeOnce)
	}

	func clear() {
		dict.removeAll()
		if let cacheSubdirectoryName = cacheSubdirectoryName {
			FileManager.removeRecursively(FileManager.cacheDirectory(subDirectory: "Mux/" + cacheSubdirectoryName, create: false))
		}
	}

	func clearMemory(key: K) {
		dict.removeValue(forKey: key)
	}

	var cacheSubdirectoryName: String? {
		return nil
	}
}


extension FileManager {

	fileprivate class func cacheDirectory(subDirectory: String, create: Bool) -> String {
		guard var result = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
			preconditionFailure("No cache directory")
		}
		result += "/" + subDirectory
		if create && !`default`.fileExists(atPath: result) {
			do {
				try `default`.createDirectory(atPath: result, withIntermediateDirectories: true, attributes: nil)
			}
			catch {
				preconditionFailure("Couldn't create cache directory (\(result))")
			}
		}
		return result
	}

	fileprivate class func removeRecursively(_ path: String) {
		try? `default`.removeItem(atPath: path)
	}
}


private let jsonDecoder: JSONDecoder = { JSONDecoder() }()
private let jsonEncoder: JSONEncoder = { JSONEncoder() }()

