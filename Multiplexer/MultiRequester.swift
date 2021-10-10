//
//  MultiRequester.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 10/10/2021.
//  Copyright © 2021 Hovik Melikyan. All rights reserved.
//

import Foundation


/// EXPERIMENTAL
/// If your backend supports multiple-ID requests (such as  e.g.`/profiles/[id1,id2]`), then MultiRequester can be used in combination with an existing MultiplexerMap object to combine single and multi-requests into the same caching infrastructure. Multi-ID requests made via MultiRequester's `request(...)` method can update the map linked to it and also reuse the cached values stored by the map. Thus, objects will be cached locally regardless of whether they were requested via singular endpoints or multi-ID ones; and on the other hand, multi-ID requests can save bandwidth by reusing some of the objects already cached and requesting fewer ID's (or even none) from the backend.

open class MultiRequester<K: LosslessStringConvertible, T: Codable & Identifiable> where T.ID == K {

	public typealias OnMultiResult = (Result<[T], Error>) -> Void

	public init(map: MultiplexerMap<K, T>, onMultiFetch: @escaping ([K], @escaping OnMultiResult) -> Void) {
		self.multiplexerMap = map
		self.onMultiFetch = onMultiFetch
	}


	/// This method attempts to retrieve objects associated with the set of keys [K]. The number of the results is not guaranteed to be the same as the number of keys, neither is the order guaranteed to be the same. If the fetcher returns an error, this function may return some number of previously cached results but will also return the error object (it's why the completion has both result and error arguments). The result set is not optional but may be empty if neither the fetcher nor the caching system have any new values.
	public func request(keys: [K], completion: (([T], Error?) -> Void)?) {

		// See if there are any good non-expired cached values in the map object; also build the set of keys to be used in a call to the user's fetcher function.
		var values: [T] = []
		let remainingKeys = keys.filter {
			multiplexerMap.storedValue($0).map { value -> T? in
				values.append(value)
				return value
			} == nil
		}

		// If all results are found in cache, return them:
		if remainingKeys.isEmpty {
			completion?(values, nil)
			return
		}

		// Attempt to fetch and combine the results with the previously cached ones; in case of error use the same logic of reusing the expired cached results if it was a network error.
		onMultiFetch(remainingKeys) { newResult in
			switch newResult {

				case .success(let newValues):
					newValues.forEach {
						self.multiplexerMap.storeSuccess($0.id, value: $0)
						values.append($0)
					}
					completion?(values, nil)

				case .failure(let error):
					remainingKeys.forEach {
						self.multiplexerMap.storeFailure($0, error: error).map {
							values.append($0)
						}
					}
					completion?(values, error)
			}
		}
	}


	private let multiplexerMap: MultiplexerMap<K, T>

	private let onMultiFetch: ([K], @escaping OnMultiResult) -> Void
}
