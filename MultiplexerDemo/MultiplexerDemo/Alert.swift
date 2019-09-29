//
//  Alert.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


extension UIViewController {

	func alert(_ error: Error, onDismissed: (() -> Void)? = nil) {
		alert(title: "Oops...", message: error.localizedDescription, onDismissed: onDismissed)
	}

	func alert(title: String?, message: String? = nil, onDismissed: (() -> Void)? = nil) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default) {
			(action) in onDismissed?()
		})
		self.present(alert, animated: true)
	}
}
