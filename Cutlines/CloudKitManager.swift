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

enum CloudResult {
	
	case success
	case failure(Error)
}

struct FetchResult {
	var photo: Photo!
	var image: UIImage!
}

enum CloudFetchResult {
	
	case success([FetchResult])
	case failure(Error)
}

private class SyncState: NSObject, NSCoding {
	
	// MARK: Sync state properties (persisted)
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
	
	private let container: CKContainer
	private let privateDB: CKDatabase
	
	private let photoType = "Photo"
	
	private let captionKey = "caption"
	private let dateAddedKey = "dateAdded"
	private let dateTakenKey = "dateTaken"
	private let imageKey = "image"
	private let lastUpdatedKey = "lastUpdated"
	private let photoIDKey = "photoID"
	
	let subscriptionID = "private-changes"
	
	private let zoneName = "Photos"
	
	var imageStore: ImageStore!
	var photoDataSource: PhotoDataSource!
	
	private var syncState: SyncState!
	private var syncStateArchive: String

	init() {

		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		syncStateArchive = cacheDir.appendingPathComponent("syncState.archive").path
		
		container = CKContainer.default()
		privateDB = container.privateCloudDatabase
		
		syncState = loadSyncState()
	}
	
	func saveSyncState() {
		
		NSKeyedArchiver.archiveRootObject(syncState, toFile: syncStateArchive)
		print("SyncState saved")
	}
	
	private func loadSyncState() -> SyncState {
		
		if let syncState = NSKeyedUnarchiver.unarchiveObject(withFile: syncStateArchive) as? SyncState {
			print("SyncState loaded from archive")
			return syncState
		} else {
			print("Unable to load previous sync state, starting new")
			return SyncState()
		}
	}
	
	func save(photo: Photo, completion: @escaping (CloudResult) -> Void) {
		
		guard let recordZone = syncState.recordZone else {
			return
		}
		
		let recordID = CKRecordID(recordName: photo.photoID!, zoneID: recordZone.zoneID)
		let record = CKRecord(recordType: photoType, recordID: recordID)
		
		return save(photo: photo, toRecord: record, completion: completion)
	}
	
	func update(photo: Photo, completion: @escaping (CloudResult) -> Void) {
		
		let recordID = CKRecordID(recordName: photo.photoID!)
		privateDB.fetch(withRecordID: recordID) { (record, error) in
		
			if let error = error {
				completion(.failure(error))
			} else {
				
				guard let record = record else {
					return
				}
				
				self.save(photo: photo, toRecord: record, completion: completion)
			}
		}
	}
	
	private func save(photo: Photo, toRecord record: CKRecord, completion: @escaping (CloudResult) -> Void) {
		
		let record = getRecord(photo)
		
		privateDB.save(record) { (record, error) in
			
			if let error = error {
				print("Photo upload errored \(error)")
				completion(.failure(error))
			} else {
				print("Photo uploaded successfully")
				photo.inCloud = true
				self.photoDataSource.save()
				completion(.success)
			}
		}
	}
	
	func setup(completion: @escaping () -> Void) {
		
		createCustomZone {
			
			self.registerForSubscription {
				
				completion()
			}
		}
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
		
		if let _ = self.syncState.recordZone {
			
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
		
		privateDB.add(changeOperation)
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
		
			guard let result = self.unpack(record) else {
				return
			}
			
			self.photoDataSource.addPhoto(result.photo) { updateResult in
			
				switch updateResult {
				case .success:
					self.imageStore.setImage(result.image, forKey: result.photo.photoID!)
				case let .failure(error):
					print("Error saving photo \(error)")
				}
			}
		}
		
		operation.recordWithIDWasDeletedBlock = { (recordID, string) in
		
		}
		
		operation.recordZoneChangeTokensUpdatedBlock = { (recordZoneID, newChangeToken, lastTokenData) in
			
			self.syncState.zoneChangeToken = newChangeToken
		}
		
		operation.recordZoneFetchCompletionBlock = { (recordZoneID, newChangeToken, lastTokenData, more, error) in
			
			if let error = error {
				print("Got error fetching record changes \(error)")
				return
			}
			
			self.syncState.zoneChangeToken = newChangeToken
			
			// Completion handler originally passed to fetchChanges
			completion()
		}
			
		privateDB.add(operation)
	}
	
	private func unpack(_ record: CKRecord) -> FetchResult? {
		
		print("Got record changed with caption \((record[self.captionKey] as! NSString?)!)")
		
		let photo = self.photoDataSource.allocEmptyPhoto()
		
		photo.caption = record[self.captionKey] as! String?
		photo.dateAdded = record[self.dateAddedKey] as! NSDate?
		photo.dateTaken = record[self.dateTakenKey] as! NSDate?
		photo.lastUpdated = record[self.lastUpdatedKey] as! NSDate?
		photo.photoID = record[self.photoIDKey] as! String?
		photo.inCloud = true
		
		guard let asset = record[self.imageKey] as? CKAsset else {
			print("Unable to get CKAsset from record")
			return nil
		}
		
		let imageData: Data
		do {
			imageData = try Data(contentsOf: asset.fileURL)
		} catch {
			print("Unable to get Data from CKAsset \(error)")
			return nil
		}
		
		guard let image = UIImage(data: imageData) else {
			print("Unable to get UIImage from Data")
			return nil
		}
		
		var fetchResult = FetchResult()
		fetchResult.photo = photo
		fetchResult.image = image
		return fetchResult
	}
	
	func fetchAll(completion: @escaping (CloudFetchResult) -> Void) {
		
		let query = CKQuery(recordType: photoType, predicate: NSPredicate(value: true))
		
		privateDB.perform(query, inZoneWith: nil) { (results, error) in
			
			if let error = error {
				print("photo fetchAll failed \(error)")
				completion(.failure(error))
			} else {
				
				print("photo fetchAll succeeded")
				var fetchResults = [FetchResult]()
				
				defer {
					completion(.success(fetchResults))
				}
				
				if let results = results {
					
					for record in results {
						
						guard let fetchResult = self.unpack(record) else {
							return
						}
						
						fetchResults.append(fetchResult)
					}
				}
			}
		}
	}
	
	private func getRecord(_ photo: Photo) -> CKRecord {
		
		let imageURL = imageStore.imageURL(forKey: photo.photoID!)
		
		let record = CKRecord(recordType: photoType)
		record[captionKey] = photo.caption as NSString?
		record[dateAddedKey] = photo.dateAdded
		record[dateTakenKey] = photo.dateTaken
		record[imageKey] = CKAsset(fileURL: imageURL)
		record[lastUpdatedKey] = photo.lastUpdated
		record[photoIDKey] = photo.photoID as NSString?
		
		return record
	}
	
	func pushLocalPhotos(batchSize: Int = 5) {
		
		let localPhotos = photoDataSource.fetchOnlyLocal(limit: batchSize)
		
		if localPhotos.isEmpty {
			return
		}
		
		let records = localPhotos.map { getRecord($0) }
		
		let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
		operation.perRecordCompletionBlock = { (record, error) in
			
			if let error = error {
				print("Error saving photo in batch \(error)")
				
				guard let ckErr = error as? CKError else {
					
					print("Couldn't cast error as CKError")
					return
				}
				
				// The cloud already has this record,
				// mark it saved below
				if ckErr.code != .serverRecordChanged {
					return
				}				
			}
			
			let photoID = record[self.photoIDKey] as! String?
			let savedPhoto = localPhotos.first { $0.photoID! == photoID! }
			
			savedPhoto?.inCloud = true
			self.photoDataSource.save()
		}
		
		operation.modifyRecordsCompletionBlock = { (saved, deleted, error) in
			
			if let error = error {
				print("Error saving photos with batch size \(batchSize) - \(error)")
				
				guard let ckErr = error as? CKError else {
					print("Couldn't cast error as CKError")
					return
				}
				
				if ckErr.code == .limitExceeded {
					print("Retrying push with half of batchSize")
					self.pushLocalPhotos(batchSize: batchSize / 2)
				}
			} else {
				
				// Attempt another batch
				if let saved = saved {
					print("Uploaded \(saved.count) photos to the cloud")
				}
				
				self.pushLocalPhotos()
			}
		}
		
		privateDB.add(operation)
	}
	
	// For development/sanity check purposes
	private func verifyUnique() {
		
		self.fetchAll { updateresult in
			
			switch updateresult {
				
			case .failure:
				break
			case let .success(fetchrequests):
				
				var myset = Set<String>()
				for res in fetchrequests {
					
					let id = res.photo.photoID!
					assert(!myset.contains(id))
					myset.insert(id)
				}
			}
		}
	}
}
