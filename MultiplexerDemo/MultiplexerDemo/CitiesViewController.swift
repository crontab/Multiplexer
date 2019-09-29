//
//  CitiesViewController.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


let initialLocationIDs = [2459115, 44418, 615702, 650272, 1118370] // NY, London, Paris, Frankfurt, Tokyo


class CityCell: UITableViewCell {
}


class CitiesViewController: UITableViewController {

	override func viewDidLoad() {
		super.viewDidLoad()

		Backend.fetchWeather(locationId: initialLocationIDs.first!) { (result) in
			print(result)
		}
	}

	// MARK: - Table view data source

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 0
	}
}
