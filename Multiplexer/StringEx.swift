//
//  StringEx.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 28/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


extension String {

	func toURLSafeHash(max: Int) -> String {
		return String(toSHA256().toURLSafeBase64().suffix(max))
	}

	func toSHA256() -> Data {
		return (data(using: .utf8) ?? Data()).toSHA256()
	}
}


extension Data {

	func toHexString() -> String {
		return map { String(format: "%.2hhx", $0) }.joined()
	}

	func toURLSafeBase64() -> String {
		return base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "_").replacingOccurrences(of: "=", with: "")
	}

	func toSHA256() -> Data {
		var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
		withUnsafeBytes {
			_ = CC_SHA256($0.baseAddress, CC_LONG(count), &hash)
		}
		return Data(hash)
	}
}
