//
//  Request.swift
//  MultiplexerDemo
//
//  Created by Hovik Melikyan on 29/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class Request {

	private var urlRequest: URLRequest


	init(path: String) {
		urlRequest = .init(url: URL(string: "https://www.metaweather.com/api")!.appendingPathComponent(path))
		#if PRINT_REQUEST_URL
			print(urlRequest.httpMethod ?? "GET", urlRequest.url!)
		#endif
	}


	func perform<T: Codable>(type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
		perform { (result) in
			switch result {

			case .failure(let error):
				completion(.failure(error))

			case .success(let data):
				do {
					let object = try Self.jsonDecoder.decode(type, from: data)
					#if PRINT_JSON
						print("<<<", self.urlRequest.url!.absoluteString)
						print(try! JSONSerialization.jsonObject(with: data, options: []))
					#endif
					completion(.success(object))
				}
				catch {
					#if PRINT_JSON
						print("<<<", self.urlRequest.url!.absoluteString)
						print(String(data: data, encoding: .utf8) ?? "")
						switch error {
						// The below prints the JSON path that caused the decoding fail
						case DecodingError.dataCorrupted(let context), DecodingError.keyNotFound(_, let context), DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context):
							print("JSON error:", context.debugDescription, "-", context.codingPath.map({ $0.stringValue}).joined(separator: "/"))
						default:
							print("JSON error:", error.localizedDescription)
					}
					#endif
					completion(.failure(AppError.app(code: "invalid_json_response")))
				}
			}
		}
	}


	func perform(completion: @escaping (Result<Data, Error>) -> Void) {
		let task = Self.sharedSession.dataTask(with: urlRequest) { (data, basicResponse, error) in

			if let error = error {
				print(error)
				completion(.failure(error))
				return
			}

			let response = basicResponse as! HTTPURLResponse

			if response.statusCode >= 100 && response.statusCode < 200 {
			}

			else if response.statusCode >= 200 && response.statusCode < 300 {
				completion(.success(data ?? Data()))
			}

			// HTTP status >= 300
			else {
				if let data = data {
					#if PRINT_JSON
						print("<<< HTTP \(response.statusCode)", self.urlRequest.url!.absoluteString)
						print(String(data: data, encoding: .utf8) ?? "")
					#endif
					let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
					if let backendCode = dict?["detail"] as? String {
						completion(.failure(AppError.backend(code: backendCode)))
					}
					else {
						completion(.failure(AppError.http(code: response.statusCode)))
					}
				}
				else {
					completion(.failure(AppError.http(code: response.statusCode)))
				}
			}
		}

		task.resume()
	}


	private static let sharedSession: URLSession = {
		return URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: .main)
	}()


	private static let jsonDecoder: JSONDecoder = {
		let result = JSONDecoder()
		result.keyDecodingStrategy = .convertFromSnakeCase
		result.dateDecodingStrategy = .formatted(DateFormatter.iso8601WithMS)
		return result
	}()


	private static let jsonEncoder: JSONEncoder = {
		let result = JSONEncoder()
		result.keyEncodingStrategy = .convertToSnakeCase
		result.dateEncodingStrategy = .formatted(DateFormatter.iso8601WithMS)
		return result
	}()
}


extension DateFormatter {

	static let iso8601WithMS: DateFormatter = {
		let dateFmt = DateFormatter()
		dateFmt.calendar = Calendar(identifier: .iso8601)
		dateFmt.locale = Locale(identifier: "en_US_POSIX")
		dateFmt.timeZone = TimeZone(secondsFromGMT: 0)
		dateFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
		return dateFmt
	}()

}


enum AppError: LocalizedError {
	case http(code: Int)
	case backend(code: String)
	case app(code: String)

	public var errorDescription: String? {
		switch self {
		case .http(let code):
			return String(format: "HTTP %d", code)
		case .backend(let code):
			return code
		case .app(let code):
			return code
		}
	}
}
