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
	
	var failureMode = false
	
	override init() {
	}
	
	override func setup(completion: (() -> Void)?) {
		completion?()
	}
	
	override func setupNoSync(completion: (() -> Void)?) {
		completion?()
	}
	
	override func pushNew(pairs: [PhotoPair], longLived: Bool, completion: @escaping (CloudPushResult) -> Void) {
		let result = failureMode ? failResult() : .success
		completion(result)
	}
	
	override func pushModified(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		let result = failureMode ? failResult() : .success
		completion(result)
	}
	
	override func delete(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		let result = failureMode ? failResult() : .success
		completion(result)
	}
	
	override func fetchChanges(completion: @escaping () -> Void) {
		completion()
	}
	
	func failResult() -> CloudPushResult {
		return .failure(CKError(_nsError: NSError(domain: "", code: 0, userInfo: nil)))
	}
}
