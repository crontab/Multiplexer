//
//  MultiRequester.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 10/10/2021.
//  Copyright © 2021 Hovik Melikyan. All rights reserved.
//

import Foundation


public protocol Identifiable {
	associatedtype K
	var key: K { get }
}


open class MultiRequester<K: MuxKey, T: Codable & Identifiable> where T.K == K {

	public typealias OnMultiResult = (Result<[T], Error>) -> Void

	public init(map: MultiplexerMap<K, T>, onMultiFetch: @escaping ([K], OnMultiResult) -> Void) {
		self.map = map
		self.onMultiFetch = onMultiFetch
	}


	public func request(keys: [K], completion: OnMultiResult?) {

		var prevResults: [T] = []
		let remainingKeys = keys.filter {
			if let value = map.storedValue($0) {
				prevResults.append(value)
				return false
			}
			return true
		}

		if remainingKeys.isEmpty {
			completion?(.success(prevResults))
			return
		}

		onMultiFetch(remainingKeys) { newResult in
			switch newResult {

				case .success(let values):
					values.forEach {
						self.map.storeSuccess($0.key, value: $0)
					}
					completion?(.success(prevResults + values))

				case .failure(let error):
					remainingKeys.forEach {
						self.map.storeFailure($0, error: error)
					}
					completion?(.failure(error))
			}
		}
	}


	private let map: MultiplexerMap<K, T>

	private let onMultiFetch: ([K], @escaping OnMultiResult) -> Void
}
