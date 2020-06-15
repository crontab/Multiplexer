//
//  Backend.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class Backend {

	static func fetchWeather(locationId: Int, completion: @escaping (Result<FullLocation, Error>) -> Void) {
		Request(path: "/location/\(locationId)/").perform(type: FullLocation.self, completion: completion)
	}

	static func search(text: String, completion: @escaping (Result<[Location], Error>) -> Void) {
		Request(path: "/location/search/?query=\(text.toUrlEncoded())").perform(type: [Location].self, completion: completion)
	}
}
