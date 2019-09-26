//
//  Common.swift
//  Oulala
//
//  Created by Hovik Melikyan on 06/08/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


@inlinable
internal func debugOnly(_ body: () -> Void) {
	assert({ body(); return true }())
}


@inlinable
internal func DLOG(_ s: String) {
	debugOnly {
		print(s)
	}
}
