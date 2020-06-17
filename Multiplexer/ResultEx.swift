//
//  ResultEx.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 17/06/2020.
//  Copyright © 2020 Hovik Melikyan. All rights reserved.
//

import Foundation


public extension Result {

	@inlinable
	var success: Success? {
		switch self {
		case .success(let result):
			return result
		default:
			return nil
		}
	}

	@inlinable
	var failure: Failure? {
		switch self {
		case .failure(let error):
			return error
		default:
			return nil
		}
	}

	@inlinable
	func ifSuccess(_ onSuccess: (Success) -> Void, else: (Failure) -> Void) {
		switch self {
		case .success(let result):
			onSuccess(result)
		case .failure(let error):
			`else`(error)
		}
	}
}
