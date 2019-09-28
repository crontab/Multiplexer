//
//  FileDownloader.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 06/05/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class FileDownloader: NSObject, URLSessionDownloadDelegate {

	typealias Progress = (Int64, Int64) -> Void
	typealias Completion = (Result<URL, Error>) -> Void

	private var progress: Progress?
	private var completion: Completion
	private var task: URLSessionDownloadTask!

	init(url: URL, progress: Progress?, completion: @escaping Completion) {
		self.progress = progress
		self.completion = completion
		super.init()
		let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: .main)
		self.task = session.downloadTask(with: url)
	}

	func resume() {
		task.resume()
	}

	func cancel() {
		// Triggers NSURLErrorDomain.NSURLErrorCancelled
		task.cancel()
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		if let progress = progress {
			progress(totalBytesWritten, totalBytesExpectedToWrite)
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		// `error` can be nil after a successful download; we don't need this event
		if let error = error {
			completion(.failure(error))
		}
		session.finishTasksAndInvalidate()
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		completion(.success(location))
		session.finishTasksAndInvalidate()
	}
}

