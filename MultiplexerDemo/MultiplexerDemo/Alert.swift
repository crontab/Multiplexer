//
//  Alert.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit
import Multiplexer


extension UIViewController {

	func ensure<Success, Failure>(_ result: Result<Success, Failure>, onSuccess: (Success) -> Void) {
		switch result {
		case .success(let success):
			onSuccess(success)
		case .failure(let error):
			alert(error)
		}
	}

	func alert(_ error: Error) {
		alert(error, onDismissed: nil)
	}

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
