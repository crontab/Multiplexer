//
//  main.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 25/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


struct Obj: Codable {
	var id: String
	var name: String
}


let test = Multiplexer<Obj> { onResult in
	DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
		onResult(.success(Obj(id: "0", name: "HM")))
	}
}

test.request(refresh: false) { (result) in
	print(result)
	test.request(refresh: false) { (result) in
		print(result)
	}
}


let testMap = MultiplexerMap<Obj> { (key, onResult) in
	DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
		onResult(.success(Obj(id: key, name: "User \(key)")))
	}
}


testMap.request(refresh: false, key: "1") { (result) in
	print(result)
	testMap.request(refresh: false, key: "1") { (result) in
		print(result)
		testMap.request(refresh: false, key: "2") { (result) in
			print(result)
		}
	}
}


RunLoop.main.run()
