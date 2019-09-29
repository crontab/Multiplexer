//
//  Mux.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation
import Multiplexer


// Multiplexer namespace

class Mux {

	static var weather = MultiplexerMap<LocationInfo> { (id, onResult) in
		Backend.fetchWeather(locationId: id, completion: onResult)
	}
}
