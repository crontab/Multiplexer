//
//  CitiesViewController.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit
import Multiplexer


let initialLocationIDs = ["2459115", "44418", "615702", "650272", "1118370"] // NY, London, Paris, Frankfurt, Tokyo


class CityCell: UITableViewCell {
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var tempLabel: UILabel!
	@IBOutlet weak var detailLabel: UILabel!

	func set(locationInfo: LocationInfo) {
		titleLabel.text = locationInfo.title
		if let weather = locationInfo.consolidatedWeather.first {
			tempLabel.text = "\(Int(weather.theTemp))º"
			detailLabel.text = weather.weatherStateName
		}
		else {
			tempLabel.text = nil
			detailLabel.text = nil
		}
	}
}


class CitiesViewController: UITableViewController {

	private var locations: [LocationInfo] = []

	private var locationIDs: [String] { locations.map { $0.idAsString } }


	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.refreshControl = UIRefreshControl()
		tableView.sendSubviewToBack(tableView.refreshControl!)
		tableView.refreshControl?.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)

		refreshLocations(force: false, locationIDs: initialLocationIDs)
	}


	@objc func didPullToRefresh() {
		refreshLocations(force: true, locationIDs: locationIDs)
	}


	private func refreshLocations(force: Bool, locationIDs: [String]) {
		guard !isRefreshing else {
			return
		}
		isRefreshing = true
		let zipper = Zipper()
		initialLocationIDs.forEach {
			if force {
				Mux.weather.refresh(key: $0)
			}
			zipper.add(key: $0, Mux.weather)
		}
		zipper.sync { (results) in
			self.locations = results.compactMap({
				try? $0.get() as? LocationInfo
			})
			self.tableView.reloadData()
			self.isRefreshing = false
		}
	}


	private var isRefreshing = false {
		didSet {
			if isRefreshing {
				tableView.refreshControl?.beginRefreshing()
			}
			else {
				tableView.refreshControl?.endRefreshing()
			}
		}
	}


	// MARK: - Table view data source

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return locations.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "CityCell", for: indexPath) as! CityCell
		cell.set(locationInfo: locations[indexPath.row])
		return cell
	}
}
