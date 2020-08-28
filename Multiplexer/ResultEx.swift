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
		if case .success(let result) = self {
			return result
		}
		return nil
	}

	@inlinable
	var failure: Failure? {
		if case .failure(let error) = self {
			return error
		}
		return nil
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
