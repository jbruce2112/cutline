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
	case failure(CKError)
}

enum CloudRecordResult {
	
	case success([String: CKRecord])
	case failure(CKError)
}

// MARK: CloudChangeDelegate
protocol CloudChangeDelegate: class {
	
	func didModify(photo: CloudPhoto)
	func didRemove(photoID: String)
}

private class SyncState: NSObject, NSCoding {
	
	// MARK: Properties (persisted)
	fileprivate var dbChangeToken: CKServerChangeToken?
	fileprivate var zoneChangeToken: CKServerChangeToken?
	fileprivate var recordZone: CKRecordZone?
	fileprivate var subscribedForChanges = false
	
	override init() {
		super.init()
	}
	
	required init?(coder aDecoder: NSCoder) {
		
		subscribedForChanges = aDecoder.decodeBool(forKey: "subscribedForChanges")
		zoneChangeToken = aDecoder.decodeObject(forKey: "zoneChangeToken") as? CKServerChangeToken
		dbChangeToken = aDecoder.decodeObject(forKey: "dbChangeToken") as? CKServerChangeToken
		recordZone = aDecoder.decodeObject(forKey: "recordZone") as? CKRecordZone
	}
	
	func encode(with aCoder: NSCoder) {
		
		aCoder.encode(recordZone, forKey: "recordZone")
		aCoder.encode(dbChangeToken, forKey: "dbChangeToken")
		aCoder.encode(zoneChangeToken, forKey: "zoneChangeToken")
		aCoder.encode(subscribedForChanges, forKey: "subscribedForChanges")
	}
}

class CloudKitManager {
	
	// MARK: Properties
	private let container: CKContainer
	private let privateDB: CKDatabase
		
	let subscriptionID = "private-changes"
	
	private let zoneName = "Photos"
	
	private var syncState: SyncState!
	private var syncStateArchive: String
	
	private var ready = false
	
	weak var delegate: CloudChangeDelegate?
	
	init() {

		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		syncStateArchive = cacheDir.appendingPathComponent("syncState.archive").path
		
		container = CKContainer.default()
		privateDB = container.privateCloudDatabase
		
		syncState = loadSyncState()
	}
	
	// MARK: Functions
	func setup(completion: @escaping () -> Void) {
		
		createCustomZone {
			
			// We're ready to push once this is set
			self.ready = self.syncState.recordZone != nil
			
			self.registerForSubscription {
				
				completion()
			}
		}
	}
	
	// Setup for users of this class who don't need syncing/notifications
	func setupNoSync(completion: @escaping () -> Void) {
		
		createCustomZone {
			
			// We're ready to push once this is set
			self.ready = self.syncState.recordZone != nil
				
			completion()
		}
	}
	
	func saveSyncState() {
		
		NSKeyedArchiver.archiveRootObject(syncState, toFile: syncStateArchive)
		print("SyncState saved")
	}
	
	
	func pushNew(photos: [CloudPhoto], qos: QualityOfService?, completion: @escaping (CloudPushResult) -> Void) {
		
		if !ready || photos.isEmpty {
			return
		}
		for photo in photos {
			print("Pushing NEW photo with caption \(photo.caption!)")
		}
		
		let batchSize = photos.count
		
		// Create a CKRecord for each photo
		let zoneID = syncState.recordZone!.zoneID
		let records = photos.map { $0.getRecord(withZoneID: zoneID) }
		
		let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
		
		operation.perRecordCompletionBlock = { (record, error) in
			
			if let error = error {
				print("Error saving photo \(error)")
			}
			
			// Look up the original photo by the recordName
			let recordName = record.recordID.recordName
			let savedPhoto = photos.first { $0.photoID == recordName }
			
			// Set the CKRecord on the photo
			savedPhoto?.ckRecord = CloudPhoto.systemData(fromRecord: record)
		}
		
		operation.modifyRecordsCompletionBlock = { (saved, deleted, error) in
			
			if let error = error {
				
				print("Error saving photos with batch size \(batchSize) - \(error)")
				completion(.failure(error as! CKError))
			} else {
				
				if let saved = saved {
					print("Uploaded \(saved.count) photos to the cloud")
				}
				
				completion(.success)
			}
		}
		
		operation.qualityOfService = qos ?? .utility
		operation.allowsCellularAccess =
			appGroupDefaults.bool(forKey: Key.cellSync.rawValue)
		
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
			CloudPhoto.applyChanges(from: photo, to: record)
			
			records.append(record)
			print("Pushing UPDATE for photo with caption \(photo.caption!)")
		}
		
		let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
		
		operation.perRecordCompletionBlock = { (record, error) in
			
			// If we get a 'ServerRecordChanged' error here, it means
			// we're in a conflict case. Our local CKRecord is older
			// than what the cloud has.
			// This likely means that next time we fetch, we'll have our
			// *this* change replaced with something from the cloud.
			// Maybe we could copy this version somewhere else for recovery later.
			if let error = error {
				
				print("Error updating photo \(error)")
			} else {
				
				let recordName = record.recordID.recordName
				let updatedPhoto = photos.first { $0.photoID == recordName }
				
				// Set the updated CKRecord on the photo
				updatedPhoto?.ckRecord = CloudPhoto.systemData(fromRecord: record)
				
				print("Updated photo with new caption " +
						"'\(record["caption"] as! NSString)' and change tag \(record.recordChangeTag!)")
			}
		}
		
		operation.modifyRecordsCompletionBlock = { (saved, deleted, error) in
			
			if let error = error {
				completion(.failure(error as! CKError))
			} else {
				completion(.success)
			}
		}
		
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
			
			// This will give us a record with only
			// the system fields filled in
			let systemRecord = CloudPhoto.systemRecord(fromData: record)
			recordIDs.append(systemRecord.recordID)
		}
		
		let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
		
		operation.modifyRecordsCompletionBlock = { (saved, deleted, error) in
			
			if let error = error {
				completion(.failure(error as! CKError))
			} else {
				
				if let deleted = deleted {
					print("\(deleted.count) photos were deleted in the cloud")
				}
				completion(.success)
			}
		}
		
		operation.qualityOfService = .utility
		self.privateDB.add(operation)
	}
	
	func fetchChanges(completion: @escaping () -> Void) {
		
		var changedZoneIDs = [CKRecordZoneID]()
		
		// When our change token is nil, we'll fetch everything
		let changeOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: syncState.dbChangeToken)
		
		changeOperation.fetchAllChanges = true
		changeOperation.recordZoneWithIDChangedBlock = { (recordZoneID) in
			
			changedZoneIDs.append(recordZoneID)
		}
		
		changeOperation.changeTokenUpdatedBlock = { (newToken) in
			
			self.syncState.dbChangeToken = newToken
		}
		
		changeOperation.fetchDatabaseChangesCompletionBlock = { (newToken, more, error) in
			
			if let error = error {
				print("Got error in fetching changes \(error)")
				return
			}
			
			self.syncState.dbChangeToken = newToken
			self.fetchChanges(fromZones: changedZoneIDs, completion: completion)
		}
		
		changeOperation.qualityOfService = .utility
		changeOperation.allowsCellularAccess =
			appGroupDefaults.bool(forKey: Key.cellSync.rawValue)
		
		privateDB.add(changeOperation)
	}
	
		
	// MARK: Private functions
	private func loadSyncState() -> SyncState {
		
		if let syncState = NSKeyedUnarchiver.unarchiveObject(withFile: syncStateArchive) as? SyncState {
			print("SyncState loaded from archive")
			return syncState
		} else {
			print("Unable to load previous SyncState, starting new")
			return SyncState()
		}
	}
	
	private func fetchChanges(fromZones changedZoneIDs: [CKRecordZoneID], completion: @escaping () -> Void) {
		
		if changedZoneIDs.isEmpty {
			return
		}
		
		let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: changedZoneIDs)
		
		// We should only have one changed zone right now
		assert(changedZoneIDs.count == 1)
		guard let zoneID = changedZoneIDs.first else {
			return
		}
		
		let options = CKFetchRecordZoneChangesOptions()
		options.previousServerChangeToken = self.syncState.zoneChangeToken
		
		operation.optionsByRecordZoneID = [zoneID: options]
		operation.fetchAllChanges = true
		
		operation.recordChangedBlock = { (record) in
		
			guard let result = CloudPhoto(fromRecord: record) else {
				print("Unable to get photo from record \(record.recordID.recordName)")
				return
			}
			
			print("Fetched photo with caption '\(result.caption)' and change tag \(record.recordChangeTag!)")
			self.delegate?.didModify(photo: result)
		}
		
		operation.recordWithIDWasDeletedBlock = { (recordID, _) in
		
			let photoID = recordID.recordName
			print("Fetched delete for photo with ID \(photoID)")
			self.delegate?.didRemove(photoID: photoID)
		}
		
		operation.recordZoneChangeTokensUpdatedBlock = { (recordZoneID, newChangeToken, lastTokenData) in
			
			self.syncState.zoneChangeToken = newChangeToken
		}
		
		operation.recordZoneFetchCompletionBlock = { (recordZoneID, newChangeToken, lastTokenData, _, error) in
			
			if let error = error {
				print("Got error fetching record changes \(error)")
				return
			}
			
			self.syncState.zoneChangeToken = newChangeToken
			completion()
		}
		
		operation.qualityOfService = .utility
		operation.allowsCellularAccess =
			appGroupDefaults.bool(forKey: Key.cellSync.rawValue)
		
		privateDB.add(operation)
	}
	
	private func registerForSubscription(completion: @escaping () -> Void) {
		
		if syncState.subscribedForChanges {
			
			print("Already subscribed to changes")
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
			
			if let error = error {
				print("Error subscriping for notifications \(error)")
			} else {
				print("Subscribed to changes")
				self.syncState.subscribedForChanges = true
			}
			
			completion()
		}
		
		operation.qualityOfService = .utility
		privateDB.add(operation)
	}
	
	private func createCustomZone(completion: @escaping () -> Void) {
		
		if self.syncState.recordZone != nil {
			
			print("Already have a custom zone")
			completion()
			return
		}
		
		let zone = CKRecordZone(zoneName: self.zoneName)
		let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
		
		operation.modifyRecordZonesCompletionBlock = { (savedRecods, deletedRecordIDs, error) in
			
			if let error = error {
				print("Error creating recordZone \(error)")
			} else {
				print("Record zone successfully created")
				guard let savedZone = savedRecods?.first else {
					return
				}
				
				self.syncState.recordZone = savedZone
				
				completion()
			}
		}
		
		operation.qualityOfService = .utility
		privateDB.add(operation)
	}
}
