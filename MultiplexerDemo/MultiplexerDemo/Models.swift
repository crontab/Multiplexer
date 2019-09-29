//
//  Models.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


// MetaWeather API

class Source: Codable {
	var title: String		// "BBC"
	var url: String			// "http://www.bbc.co.uk/weather/"
}


class Location: Codable {
	var woeid: Int			// Where on Earth ID
	var title: String		// "London"
	var timezone: String	// "Europe/London"
	var lattLong: String	// "51.506321,-0.12714"
}


class WeatherBlock: Codable {
	var id: Int
	var weatherStateName: String	// "Light Rain"
	var windDirectionCompass: String	// "SSW"
	var created: Date
	var applicableDate: String		// "2019-10-03"
	var minTemp: Float				// ºC
	var maxTemp: Float
	var theTemp: Float
	var windSpeed: Float			// mph
	var windDirection: Float
	var airPressure: Float
	var humidity: Int
	var visibility: Float
	var predictability: Int
}


class LocationInfo: Codable {
	var consolidatedWeather: [WeatherBlock]
	var sources: [Source]
	var woeid: Int			// Where on Earth ID
	var title: String		// "London"
	var timezone: String	// "Europe/London"
	var lattLong: String	// "51.506321,-0.12714"

	var idAsString: String { String(woeid) }
}
