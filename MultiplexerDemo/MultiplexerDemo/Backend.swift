//
//  Backend.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class Backend {

	static func fetchWeather(locationId: String, completion: @escaping (Result<LocationInfo, Error>) -> Void) {
		Request(path: "/location/\(locationId.toUrlEncoded())/").perform(type: LocationInfo.self, completion: completion)
	}
}
