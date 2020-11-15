//
//  FileDownloader.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 06/05/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


public class FileDownloader: NSObject, URLSessionDownloadDelegate {

	public typealias Progress = (Int64, Int64) -> Void
	public typealias Completion = (Result<URL, Error>) -> Void

	private var progress: Progress?
	private var completion: Completion
	private var task: URLSessionDownloadTask!

	public required init(url: URL, progress: Progress?, completion: @escaping Completion) {
		self.progress = progress
		self.completion = completion
		super.init()
		let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: .main)
		self.task = session.downloadTask(with: url)
	}

	public func resume() {
		task.resume()
	}

	public func cancel() {
		// Triggers NSURLErrorDomain.NSURLErrorCancelled
		task.cancel()
	}

	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		if let progress = progress {
			progress(totalBytesWritten, totalBytesExpectedToWrite)
		}
	}

	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		// `error` can be nil after a successful download; we don't need this event
		if let error = error {
			completion(.failure(error))
		}
		session.finishTasksAndInvalidate()
	}

	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		completion(.success(location))
		session.finishTasksAndInvalidate()
	}
}

