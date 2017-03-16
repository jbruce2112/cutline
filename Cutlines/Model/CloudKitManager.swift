//
//  CloudKitManager.swift
//  Cutlines
//
//  Created by John on 2/23/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import CloudKit
import Foundation
import UIKit

enum CloudPushResult {
	
	case success
	case failure(Error)
}

enum CloudRecordResult {
	
	case success([String: CKRecord])
	case failure(Error)
}

// MARK: CloudChangeDelegate
protocol CloudChangeDelegate: class {
	
	func didModify(photo: CloudPhoto)
	func didRemove(photoID: String)
}

// MARK: NetworkStatusDelegate
protocol NetworkStatusDelegate: class {
	
	func statusChanged(busy: Bool)
}

class CloudKitManager {
	
	// MARK: Properties
	private let privateDB: CKDatabase
		
	let subscriptionID = "private-changes"
	
	private let zoneName = "Photos"
	
	private var syncState: SyncState!
	private let syncStateArchive: URL = {
		
		let cacheDir = FileManager.default.urls(for: .cachesDirectory,
		                                        in: .userDomainMask).first!
		return cacheDir.appendingPathComponent("syncState.archive")
	}()
	
	private let queue = DispatchQueue(label: "cutlines.ckManagerQueue")
	
	private var _ready = false
	private var ready: Bool {
		get {
			return queue.sync { _ready }
		}
		set {
			queue.sync { _ready = newValue }
		}
	}
	
	weak var delegate: CloudChangeDelegate?
	weak var networkStatusDelegate: NetworkStatusDelegate?
	
	init() {
		
		let container = CKContainer(identifier: cloudContainerDomain)
		privateDB = container.privateCloudDatabase
		
		syncState = loadSyncState()
	}
	
	// MARK: Functions
	func setup(completion: (() -> Void)?) {
		
		createCustomZone {
			
			// We're ready to push once this is set
			self.ready = self.syncState.recordZone != nil
			
			self.registerForSubscription {
				
				completion?()
			}
		}
	}
	
	// Setup for users of this class who don't need syncing/notifications
	func setupNoSync(completion: (() -> Void)?) {
		
		createCustomZone {
			
			// We're ready to push once this is set
			self.ready = self.syncState.recordZone != nil
				
			completion?()
		}
	}
	
	func saveSyncState() {
		
		NSKeyedArchiver.archiveRootObject(syncState, toFile: syncStateArchive.path)
		Log("SyncState saved")
	}
	
	
	func pushNew(pairs: [PhotoPair], qos: QualityOfService?, completion: @escaping (CloudPushResult) -> Void) {
		
		if !ready || pairs.isEmpty {
			return
		}
		
		for pair in pairs {
			Log("Pushing NEW photo with caption \(pair.photo.caption!)")
		}
		
		let batchSize = pairs.count
		
		// Create a CKRecord for each photo
		let zoneID = syncState.recordZone!.zoneID
		let records = pairs.map { CloudPhoto.createRecord(fromPair: $0, withZoneID: zoneID) }
		
		let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
		
		operation.perRecordCompletionBlock = { (record, error) in
			
			if let error = error {
				Log("Error saving photo \(error)")
			}
			
			// Look up the original photo by the recordName
			let recordName = record.recordID.recordName
			
			// Set the record on the main queue
			DispatchQueue.main.sync {
				
				let savedPair = pairs.first { $0.photo.id == recordName }
				savedPair?.photo.ckRecord = CloudPhoto.systemData(fromRecord: record)
			}
		}
		
		operation.modifyRecordsCompletionBlock = { (saved, deleted, error) in
			
			self.setNetworkBusy(false)
			
			DispatchQueue.main.async {
				
				if let error = error {
					
					Log("Error saving photos with batch size \(batchSize) - \(error)")
					self.handleError(error)
					completion(.failure(error))
				} else {
					
					if let saved = saved {
						Log("Uploaded \(saved.count) photos to the cloud")
					}
					
					completion(.success)
				}
			}
		}
		
		operation.qualityOfService = qos ?? .utility
		operation.allowsCellularAccess =
			appGroupDefaults.bool(forKey: Key.cellSync.rawValue)
		
		setNetworkBusy(true)
		privateDB.add(operation)
	}
	
	func pushModified(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		
		if !ready {
			return
		}
		
		var records = [CKRecord]()
		for photo in photos {
			
			// This will give us a record with only
			// the system fields filled in
			let record = CloudPhoto.systemRecord(fromData: photo.ckRecord!)
			
			// Set the only fields that we allow to be changed
			record[CloudPhoto.captionKey] = photo.caption! as CKRecordValue?
			record[CloudPhoto.lastUpdatedKey] = photo.lastUpdated
			
			records.append(record)
			Log("Pushing UPDATE for photo with caption \(photo.caption!)")
		}
		
		let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
		
		operation.perRecordCompletionBlock = { (record, error) in
			
			// If we get a 'ServerRecordChanged' error here, it means
			// we're in a conflict case. Our local CKRecord is older
			// than what the cloud has.
			// This likely means that next time we fetch, we'll have
			// *this* change replaced with something from the cloud.
			// Maybe we could copy this version somewhere else for recovery later.
			if let error = error {
				
				Log("Error updating photo \(error)")
			} else {
				
				let recordName = record.recordID.recordName
				
				// Update the updated record on the main queue
				DispatchQueue.main.sync {
					
					let updatedPhoto = photos.first { $0.id == recordName }
					updatedPhoto?.ckRecord = CloudPhoto.systemData(fromRecord: record)
				}
				
				Log("Updated photo with new caption " +
						"'\(record["caption"] as! NSString)' and change tag \(record.recordChangeTag!)")
			}
		}
		
		operation.modifyRecordsCompletionBlock = { (saved, deleted, error) in
			
			self.setNetworkBusy(false)
			
			DispatchQueue.main.sync {
				
				if let error = error {
					completion(.failure(error))
					self.handleError(error)
				} else {
					completion(.success)
				}
			}
		}
		
		setNetworkBusy(true)
		operation.qualityOfService = .utility
		self.privateDB.add(operation)
	}
	
	func delete(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		
		if !ready {
			return
		}
		
		var recordIDs = [CKRecordID]()
		for photo in photos {
			
			// If there's no CKRecord on this photo,
			// we likely didn't complete the cloud side of
			// the add for this yet.
			guard let record = photo.ckRecord else {
				continue
			}
			
			let systemRecord = CloudPhoto.systemRecord(fromData: record)
			recordIDs.append(systemRecord.recordID)
		}
		
		let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
		
		operation.modifyRecordsCompletionBlock = { (saved, deleted, error) in
			
			self.setNetworkBusy(false)
			
			DispatchQueue.main.async {
				
				if let error = error {
					self.handleError(error)
					completion(.failure(error))
				} else {
					
					Log("\(deleted?.count) photos were deleted in the cloud")
					completion(.success)
				}
			}
		}
		
		setNetworkBusy(true)
		operation.qualityOfService = .utility
		self.privateDB.add(operation)
	}
	
	func fetchChanges(completion: @escaping () -> Void) {
		
		var changedZoneIDs = [CKRecordZoneID]()
		
		let changeOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: syncState.dbChangeToken)
		
		changeOperation.previousServerChangeToken = self.syncState.dbChangeToken
		changeOperation.fetchAllChanges = true
		changeOperation.recordZoneWithIDChangedBlock = { (recordZoneID) in
			
			changedZoneIDs.append(recordZoneID)
		}
		
		changeOperation.changeTokenUpdatedBlock = { (newToken) in
			
			self.syncState.dbChangeToken = newToken
		}
		
		changeOperation.fetchDatabaseChangesCompletionBlock = { (newToken, more, error) in
			
			self.setNetworkBusy(false)
			
			if let error = error {
				Log("Got error in fetching changes \(error)")
				self.handleError(error)
				return
			}
			
			self.syncState.dbChangeToken = newToken
			self.fetchChanges(fromZones: changedZoneIDs, completion: completion)
		}
		
		changeOperation.qualityOfService = .utility
		changeOperation.allowsCellularAccess =
			appGroupDefaults.bool(forKey: Key.cellSync.rawValue)
		
		setNetworkBusy(true)
		privateDB.add(changeOperation)
	}
	
		
	// MARK: Private functions
	private func loadSyncState() -> SyncState {
		
		if let syncState = NSKeyedUnarchiver.unarchiveObject(withFile: syncStateArchive.path) as? SyncState {
			Log("SyncState loaded from archive")
			return syncState
		} else {
			Log("Unable to load previous SyncState, starting new")
			return SyncState()
		}
	}
	
	private func fetchChanges(fromZones changedZoneIDs: [CKRecordZoneID], completion: @escaping () -> Void) {
		
		if changedZoneIDs.isEmpty {
			completion()
			return
		}
		
		let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: changedZoneIDs)
		
		// We should only have one changed zone right now
		assert(changedZoneIDs.count == 1)
		guard let zoneID = changedZoneIDs.first else {
			completion()
			return
		}
		
		let options = CKFetchRecordZoneChangesOptions()
		options.previousServerChangeToken = self.syncState.zoneChangeToken
		
		operation.optionsByRecordZoneID = [zoneID: options]
		operation.fetchAllChanges = true
		
		operation.recordChangedBlock = { (record) in
		
			guard let result = CloudPhoto(fromRecord: record) else {
				Log("Unable to get photo from record \(record.recordID.recordName)")
				return
			}
			
			Log("Fetched photo with caption '\(result.caption)' and change tag \(record.recordChangeTag!)")
			
			DispatchQueue.main.sync {
				self.delegate?.didModify(photo: result)
			}
		}
		
		operation.recordWithIDWasDeletedBlock = { (recordID, _) in
		
			let photoID = recordID.recordName
			Log("Fetched delete for photo with ID \(photoID)")
			
			DispatchQueue.main.sync {
				self.delegate?.didRemove(photoID: photoID)
			}
		}
		
		operation.recordZoneChangeTokensUpdatedBlock = { (recordZoneID, newChangeToken, lastTokenData) in
			
			self.syncState.zoneChangeToken = newChangeToken
		}
		
		operation.recordZoneFetchCompletionBlock = { (recordZoneID, newChangeToken, lastTokenData, _, error) in
			
			self.setNetworkBusy(false)
			
			if let error = error {
				Log("Got error fetching record changes \(error)")
				self.handleError(error)
				completion()
				return
			}
			
			self.syncState.zoneChangeToken = newChangeToken
			completion()
		}
		
		operation.qualityOfService = .utility
		operation.allowsCellularAccess =
			appGroupDefaults.bool(forKey: Key.cellSync.rawValue)
		
		setNetworkBusy(true)
		privateDB.add(operation)
	}
	
	private func registerForSubscription(completion: @escaping () -> Void) {
		
		if syncState.subscribedForChanges {
			
			Log("Already subscribed to changes")
			completion()
			return
		}
		
		let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
		
		let notification = CKNotificationInfo()
		// The user isn't prompted when just this property is set
		notification.shouldSendContentAvailable = true
		subscription.notificationInfo = notification
		
		let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription],
		                                               subscriptionIDsToDelete: [])
		operation.modifySubscriptionsCompletionBlock = { (_, _, error) in
			
			self.setNetworkBusy(false)
			
			if let error = error {
				Log("Error subscriping for notifications \(error)")
				self.handleError(error)
			} else {
				Log("Subscribed to changes")
				self.syncState.subscribedForChanges = true
			}
			
			completion()
		}
		
		setNetworkBusy(true)
		operation.qualityOfService = .utility
		privateDB.add(operation)
	}
	
	private func createCustomZone(completion: @escaping () -> Void) {
		
		if self.syncState.recordZone != nil {
			
			Log("Already have a custom zone")
			completion()
			return
		}
		
		let zone = CKRecordZone(zoneName: self.zoneName)
		let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
		
		operation.modifyRecordZonesCompletionBlock = { (savedRecods, deletedRecordIDs, error) in
			
			self.setNetworkBusy(false)
			
			if let error = error {
				Log("Error creating recordZone \(error)")
				self.handleError(error)
			} else {
				Log("Record zone successfully created")
				guard let savedZone = savedRecods?.first else {
					return
				}
				
				self.syncState.recordZone = savedZone
				
				completion()
			}
		}
		
		setNetworkBusy(true)
		operation.qualityOfService = .utility
		privateDB.add(operation)
	}
	
	private func handleError(_ error: Error) {
		
		guard let ckError = error as? CKError else {
			return
		}
		
		switch ckError.code {
		case .userDeletedZone, .zoneNotFound, .changeTokenExpired:
			
			Log("Resetting syncState due to CKError: \(error.localizedDescription)")
			ready = false
			try? FileManager.default.removeItem(at: syncStateArchive)
			syncState.reset()
			setup(completion: nil)
		default:
			break
		}
	}
	
	// Manages the network activity icon in the status bar
	// by maintaining a count of callers passing busy true/false
	private func setNetworkBusy(_ busy: Bool) {
		
		// Static variables need to be attached to a type
		struct ActiveOperations {
			static var num = 0
		}
		
		queue.async {
			
			if busy {
				ActiveOperations.num += 1
			} else {
				ActiveOperations.num -= 1
			}
			
			assert(ActiveOperations.num >= 0)
			
			self.networkStatusDelegate?.statusChanged(busy: ActiveOperations.num > 0)
		}
	}
}
