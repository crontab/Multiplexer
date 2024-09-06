//
//  ErrorEx.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 28/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


extension Error {
	var isConnectivityError: Bool {
		let nsError = self as NSError
		switch nsError.domain {
			case NSURLErrorDomain:
				return [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost].contains((self as NSError).code)
			case "RevenueCat.ErrorCode":
				return nsError.code == 35
			default:
				return false
		}
	}
}
