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
	@IBOutlet private var titleLabel: UILabel!
	@IBOutlet private var tempLabel: UILabel!
	@IBOutlet private var condImageView: UIImageView!

	private var locationID: Int = 0

	func set(locationInfo: FullLocation) {
		locationID = locationInfo.woeid
		titleLabel.text = locationInfo.title
		if let weather = locationInfo.consolidatedWeather.first {
			tempLabel.text = "\(Int(weather.theTemp))º"
			condImageView.image = nil
			ImageLoader.main.request(url: URL(string: "https://www.metaweather.com/static/img/weather/png/64/\(weather.weatherStateAbbr).png")!) { (result) in
				guard locationInfo.woeid == self.locationID else { return }
				self.condImageView.image = result.success
			}
		}
		else {
			tempLabel.text = nil
			condImageView.image = nil
		}
	}
}



class CitiesViewController: UITableViewController {

	// Cache weather information per location for 30 minutes. If the connection is lost, this object will bring the last result stored on the cache.
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
		refreshLocations(force: true, locationIDs: locations.isEmpty ? initialLocationIDs : locations.map { $0.woeid })
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
			self.locations = results.compactMap {
				switch $0 {
				case .failure(let error):
					lastError = error
					return nil
				case .success(let any):
					return any as? FullLocation
				}
			}

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


	@IBSegueAction private func addLocationAction(_ coder: NSCoder) -> AddCityViewController? {
		return AddCityViewController(coder: coder) { [weak self] (location) in
			guard let self = self else { return }
			self.locations.removeAll { $0.woeid == location.woeid }
			self.isRefreshing = true
			Self.fullLocationMux.request(key: location.woeid) { (result) in
				self.isRefreshing = false
				self.ensure(result) { (fullLocation) in
					self.locations.insert(fullLocation, at: 0)
					self.tableView.reloadData()
				}
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

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			locations.remove(at: indexPath.row)
			tableView.deleteRows(at: [indexPath], with: .fade)
		}
	}
}
