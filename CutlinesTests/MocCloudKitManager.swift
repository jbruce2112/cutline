//
//  MocCloudKitManager.swift
//  Cutlines
//
//  Created by John on 3/13/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import CloudKit
import Foundation
@testable import Cutlines

// MocCloudKitManager implementation no-ops all cloud calls
// and instantly calls the completion handler. For unit testing.
class MocCloudKitManager: CloudKitManager {
	
	override init() {
	}
	
	override func setup(completion: @escaping () -> Void) {
		completion()
	}
	
	override func setupNoSync(completion: @escaping () -> Void) {
		completion()
	}
	
	override func pushNew(pairs: [PhotoPair], qos: QualityOfService?, completion: @escaping (CloudPushResult) -> Void) {
		completion(.success)
	}
	
	override func pushModified(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		completion(.success)
	}
	
	override func delete(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		completion(.success)
	}
	
	override func fetchChanges(completion: @escaping () -> Void) {
		completion()
	}
}

// FailCloudKitManager implementation no-ops all cloud calls
// and instantly calls the completion handler with an error. For unit testing.
class FailCloudKitManager: CloudKitManager {
	
	override init() {
	}
	
	override func setup(completion: @escaping () -> Void) {
		completion()
	}
	
	override func setupNoSync(completion: @escaping () -> Void) {
		completion()
	}
	
	override func pushNew(pairs: [PhotoPair], qos: QualityOfService?, completion: @escaping (CloudPushResult) -> Void) {
		completion(failResult())
	}
	
	override func pushModified(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		completion(failResult())
	}
	
	override func delete(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		completion(failResult())
	}
	
	override func fetchChanges(completion: @escaping () -> Void) {
		completion()
	}
	
	func failResult() -> CloudPushResult {
		return .failure(CKError(_nsError: NSError(domain: "", code: 0, userInfo: nil)))
	}
}
