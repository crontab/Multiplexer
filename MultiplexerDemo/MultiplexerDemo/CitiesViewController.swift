//
//  CitiesViewController.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit
import Multiplexer


let initialLocationIDs = [2459115, 44418, 615702, 650272, 1118370] // NY, London, Paris, Frankfurt, Tokyo


class CityCell: UITableViewCell {
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var tempLabel: UILabel!
	@IBOutlet weak var detailLabel: UILabel!

	func set(locationInfo: FullLocation) {
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

	// Cache weather information per location for 30 minutes. This can be helpful when e.g. re-adding a previously removed city. Pull-to-refresh though causes a refresh of data anyway.
	static var fullLocationMux = MultiplexerMap<Int, FullLocation>(onKeyFetch: { (id, onResult) in
		Backend.fetchWeather(locationId: id, completion: onResult)
	}).register()


	private var locations: [FullLocation] = []


	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.tableFooterView = UIView(frame: .zero)

		tableView.refreshControl = UIRefreshControl()
		tableView.sendSubviewToBack(tableView.refreshControl!)
		tableView.refreshControl?.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)

		refreshLocations(force: false, locationIDs: initialLocationIDs)
	}


	@objc func didPullToRefresh() {
		refreshLocations(force: true, locationIDs: locations.map { $0.woeid })
	}


	private func refreshLocations(force: Bool, locationIDs: [Int]) {
		guard !isRefreshing else {
			return
		}
		isRefreshing = true

		// Create a zipper chain with the locationIDs. The zipper will request full location information for each ID in parallel.
		let zipper = Zipper()

		locationIDs.forEach {
			if force {
				Self.fullLocationMux.refresh(key: $0)
			}
			zipper.add(key: $0, Self.fullLocationMux)
		}

		zipper.sync { (results) in
			var lastError: Error?

			// Get the results or otherwise store the last error object to be shown as an alert
			self.locations = results.compactMap({
				switch $0 {
				case .failure(let error):
					lastError = error
					return nil
				case .success(let any):
					return any as? FullLocation
				}
			})

			if let error = lastError {
				self.alert(error)
			}
			else {
				// Make sure the order is correct (it should be, unless there is a bug in the Multiplexer framework)
				for i in locationIDs.indices {
					precondition(self.locations[i].woeid == locationIDs[i])
				}
				self.tableView.reloadData()
			}

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


	@IBAction func addAction(_ sender: Any) {
		let addCity = storyboard!.instantiateViewController(withIdentifier: "AddCity") as! AddCityViewController
		addCity.onLocationSelected = { [weak self] (location) in
			guard let self = self else { return }
			self.locations.removeAll { $0.woeid == location.woeid }
			self.isRefreshing = true
			Self.fullLocationMux.request(key: location.woeid) { (result) in
				self.isRefreshing = false
				switch result {
				case .failure(let error):
					self.alert(error)
				case .success(let fullLocation):
					self.locations.insert(fullLocation, at: 0)
					self.tableView.reloadData()
				}
			}
		}
		navigationController!.pushViewController(addCity, animated: true)
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

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			locations.remove(at: indexPath.row)
			tableView.deleteRows(at: [indexPath], with: .fade)
		}
	}
}
