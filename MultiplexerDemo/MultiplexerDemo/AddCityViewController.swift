//
//  AddCityViewController.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit
import Multiplexer


class AddCityViewController: UITableViewController, UISearchBarDelegate {

	@IBOutlet weak var searchBar: UISearchBar!

	var onLocationSelected: ((Location) -> Void)!

	private var results: [Location] = []
	private var debouncer: DebouncerVar<String>!


	override func viewDidLoad() {
		super.viewDidLoad()

		debouncer = DebouncerVar("", delay: 1) { [weak self] in
			if let self = self {
				self.performSearch(self.searchBar.text ?? "")
			}
		}

		tableView.tableFooterView = UIView(frame: .zero)
		searchBar.becomeFirstResponder()
	}


	private func performSearch(_ text: String) {
		guard !text.isEmpty else {
			return
		}
		Backend.search(text: text) { (result) in
			self.ensure(result) { (locations) in
				self.results = locations
				self.tableView.reloadData()
			}
		}
	}


	// MARK: - Search bar delegate

	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		if !searchText.isEmpty {
			debouncer.value = searchText
		}
	}

	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		debouncer.value = searchBar.text ?? ""
		view.endEditing(false)
	}


	// MARK: - Table view data source

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return results.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "AddCityCell", for: indexPath)
		cell.textLabel?.text = results[indexPath.row].title
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		onLocationSelected(results[indexPath.row])
		tableView.deselectRow(at: indexPath, animated: true)
		navigationController!.popViewController(animated: true)
	}
}
