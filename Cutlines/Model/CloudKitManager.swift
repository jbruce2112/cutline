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

/// Passed to the completion handler
/// with the result of calls by this class
enum CloudPushResult {
	
	case success
	case failure(Error)
}

/// Custom errors emitted by CloudKitManager
enum CloudManagerError: Error {
	
	case notReady
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

/// CloudKitManager is responsible for all communication
/// with the CloudKit endpoint. It manages database/container
/// creation, client sync state, and error handling related
/// to resetting sync state. This class is thread-safe.
class CloudKitManager {
	
	// MARK: Properties
		
	let subscriptionID = "private-changes"
	
	private let zoneName = "Photos"
	
	private let privateDB: CKDatabase
	private let cloudContainer: CKContainer
	
	private var syncState: SyncState!
	private let syncStateArchive: URL = {
		
		let cacheDir = FileManager.default.urls(for: .cachesDirectory,
		                                        in: .userDomainMask).first!
		return cacheDir.appendingPathComponent("syncState.archive")
	}()
	
	/// Queue that ensures thread safety - internal to this class
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
	
	weak var cloudChangeDelegate: CloudChangeDelegate?
	weak var networkStatusDelegate: NetworkStatusDelegate?
	
	init() {
		
		cloudContainer = CKContainer(identifier: cloudContainerDomain)
		privateDB = cloudContainer.privateCloudDatabase
		
		syncState = loadSyncState()
	}
	
	// MARK: Functions
	
	/// Creates custom zones and registers for push notifications
	func setup(completion: (() -> Void)?) {
		
		createCustomZone {
			
			// We're ready to push once this is set
			self.ready = self.syncState.recordZone != nil
			
			self.registerForSubscription {
				
				completion?()
			}
		}
	}
	
	/// Setup for users of this class who don't need syncing/notifications
	func setupNoSync(completion: (() -> Void)?) {
		
		createCustomZone {
			
			// We're ready to push once this is set
			self.ready = self.syncState.recordZone != nil
				
			completion?()
		}
	}
	
	/// Saves the current SyncState to disk
	func saveSyncState() {
		
		NSKeyedArchiver.archiveRootObject(syncState, toFile: syncStateArchive.path)
		log("SyncState saved")
	}
	
	
	///	Pushes a batch of photos
	func pushNew(pairs: [PhotoPair], longLived: Bool, completion: @escaping (CloudPushResult) -> Void) {
		
		if !ready || pairs.isEmpty {
			completion(.failure(CloudManagerError.notReady))
			return
		}
		
		for pair in pairs {
			log("Pushing NEW photo with caption \(pair.photo.caption!)")
		}
		
		let batchSize = pairs.count
		
		// Create a CKRecord for each photo
		let zoneID = syncState.recordZone!.zoneID
		let records = pairs.map { CloudPhoto.createRecord(fromPair: $0, withZoneID: zoneID) }
		
		let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
		
		operation.isLongLived = longLived
		operation.longLivedOperationWasPersistedBlock = { () in
			
			log("LongLivedOperationWasPersisted")
			
			DispatchQueue.main.async {
				completion(.success)
			}
		}
		
		operation.perRecordCompletionBlock = { (record, error) in
			
			if let error = error {
				log("Error saving photo \(error)")
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
					
					log("Error saving photos with batch size \(batchSize) - \(error)")
					self.handleError(error)
					completion(.failure(error))
				} else {
					
					if let saved = saved {
						log("Uploaded \(saved.count) photos to the cloud")
					}
					
					completion(.success)
				}
			}
		}
		
		operation.qualityOfService = .utility
		operation.allowsCellularAccess =
			appGroupDefaults.bool(forKey: PrefKey.cellSync)
		
		setNetworkBusy(true)
		privateDB.add(operation)
	}
	
	/// Pushes an array of existing photos with with updates
	func pushModified(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		
		if !ready {
			completion(.failure(CloudManagerError.notReady))
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
			log("Pushing UPDATE for photo with caption \(photo.caption!)")
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
				
				log("Error updating photo \(error)")
			} else {
				
				let recordName = record.recordID.recordName
				
				// Update the updated record on the main queue
				DispatchQueue.main.sync {
					
					let updatedPhoto = photos.first { $0.id == recordName }
					updatedPhoto?.ckRecord = CloudPhoto.systemData(fromRecord: record)
				}
				
				log("Updated photo with new caption " +
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
	
	/// Pushes an array of photos to delete
	func delete(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		
		if !ready {
			completion(.failure(CloudManagerError.notReady))
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
					
					let deleteCount = deleted == nil ? 0 : deleted!.count
					log("\(deleteCount) photos were deleted in the cloud")
					completion(.success)
				}
			}
		}
		
		setNetworkBusy(true)
		operation.qualityOfService = .utility
		self.privateDB.add(operation)
	}
	
	/// Fetches changes from the cloud for all zones
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
				log("Got error in fetching changes \(error)")
				self.handleError(error)
				completion()
				return
			}
			
			self.syncState.dbChangeToken = newToken
			self.fetchChanges(fromZones: changedZoneIDs, completion: completion)
		}
		
		changeOperation.qualityOfService = .utility
		changeOperation.allowsCellularAccess =
			appGroupDefaults.bool(forKey: PrefKey.cellSync)
		
		setNetworkBusy(true)
		privateDB.add(changeOperation)
	}
		
	// MARK: Private functions
	
	/// Loads the syncState from disk (if any)
	private func loadSyncState() -> SyncState {
		
		guard let data = try? Data(contentsOf: syncStateArchive) else {
			log("Cannot read existing SyncState, starting new")
			return SyncState()
		}
		
		do {
			
			let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
			if let syncState = try unarchiver.decodeTopLevelObject(forKey: "root") as? SyncState {
				log("SyncState loaded from archive")
				return syncState
			}
		} catch {
			
			// This likely happened to the binary's name change, delete the old archive and start again
			try? FileManager.default.removeItem(at: syncStateArchive)
			log("Unable to load previous SyncState due to error \(error), starting new")
			return SyncState()
		}
		
		
		log("Unable to load previous SyncState, starting new")
		return SyncState()
	}
	
	/// Fetches changes from the cloud for the specified zones
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
				log("Unable to get photo from record \(record.recordID.recordName)")
				return
			}
			
			log("Fetched photo with caption '\(result.caption)' and change tag \(record.recordChangeTag!)")
			
			DispatchQueue.main.sync {
				self.cloudChangeDelegate?.didModify(photo: result)
			}
		}
		
		operation.recordWithIDWasDeletedBlock = { (recordID, _) in
		
			let photoID = recordID.recordName
			log("Fetched delete for photo with ID \(photoID)")
			
			DispatchQueue.main.sync {
				self.cloudChangeDelegate?.didRemove(photoID: photoID)
			}
		}
		
		operation.recordZoneChangeTokensUpdatedBlock = { (recordZoneID, newChangeToken, lastTokenData) in
			
			self.syncState.zoneChangeToken = newChangeToken
		}
		
		operation.recordZoneFetchCompletionBlock = { (recordZoneID, newChangeToken, lastTokenData, _, error) in
			
			defer {
				completion()
			}
			
			self.setNetworkBusy(false)
			
			if let error = error {
				log("Got error fetching record changes \(error)")
				self.handleError(error)
				return
			}
			
			self.syncState.zoneChangeToken = newChangeToken
		}
		
		operation.qualityOfService = .utility
		operation.allowsCellularAccess =
			appGroupDefaults.bool(forKey: PrefKey.cellSync)
		
		setNetworkBusy(true)
		privateDB.add(operation)
	}
	
	/// registers for push notifications for updates to this database
	private func registerForSubscription(completion: @escaping () -> Void) {
		
		if syncState.subscribedForChanges {
			
			log("Already subscribed to changes")
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
			
			defer {
				completion()
			}
			
			self.setNetworkBusy(false)
			
			if let error = error {
				log("Error subscriping for notifications \(error)")
				self.handleError(error)
			} else {
				log("Subscribed to changes")
				self.syncState.subscribedForChanges = true
			}
		}
		
		setNetworkBusy(true)
		operation.qualityOfService = .utility
		privateDB.add(operation)
	}
	
	/// Creates the custom zone for this user that all records are stored in
	private func createCustomZone(completion: @escaping () -> Void) {
		
		if self.syncState.recordZone != nil {
			
			log("Already have a custom zone")
			completion()
			return
		}
		
		let zone = CKRecordZone(zoneName: self.zoneName)
		let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
		
		operation.modifyRecordZonesCompletionBlock = { (savedRecods, deletedRecordIDs, error) in
			
			defer {
				completion()
			}
			
			self.setNetworkBusy(false)
			
			if let error = error {
				log("Error creating recordZone \(error)")
				self.handleError(error)
			} else {
				log("Record zone successfully created")
				guard let savedZone = savedRecods?.first else {
					return
				}
				
				self.syncState.recordZone = savedZone
			}
		}
		
		setNetworkBusy(true)
		operation.qualityOfService = .utility
		privateDB.add(operation)
	}
	
	/// Parses the error and takes any necessary actions
	private func handleError(_ error: Error) {
		
		guard let ckError = error as? CKError else {
			return
		}
		
		switch ckError.code {
		case .partialFailure:
			
			// Get the errors of all failed records if it was a partialFailure
			guard
				let errorDict = ckError.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary,
				let errors = errorDict.allValues as? [CKError] else {
					return
			}
			
			for error in errors {
				
				if handleCKError(code: error.code) {
					// Stop processing errors if we reset the syncState
					return
				}
			}
			
		default:
			handleCKError(code: ckError.code)
		}
	}
	
	/// Handles any necessary actions for the passed CKError Code
	@discardableResult
	private func handleCKError(code: CKError.Code) -> Bool {
	
		// Handle te CKErrorCode and return whether or not we reset the syncState
		switch code {
			
		case .userDeletedZone, .zoneNotFound, .changeTokenExpired:
			
			log("Resetting syncState due to CKError: \(code)")
			
			ready = false
			try? FileManager.default.removeItem(at: syncStateArchive)
			syncState.reset()
			setup(completion: nil)
			return true
		default:
			return false
		}
	}
	
	/// Manages the network activity icon in the status bar
	/// by maintaining a count of callers passing busy true/false
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
