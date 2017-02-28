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

struct FetchResult {
	var photo: Photo!
	var image: UIImage!
}

enum CloudFetchResult {
	
	case success([FetchResult])
	case failure(Error)
}

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
	
	func didModify(photo: Photo, withImage image: UIImage)
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
	
	private let photoType = "Photo"
	
	private let captionKey = "caption"
	private let dateAddedKey = "dateAdded"
	private let dateTakenKey = "dateTaken"
	private let imageKey = "image"
	private let lastUpdatedKey = "lastUpdated"
	private let photoIDKey = "photoID"
	
	let subscriptionID = "private-changes"
	
	private let zoneName = "Photos"
	
	private var syncState: SyncState!
	private var syncStateArchive: String
	
	private var ready = false
	
	weak var delegate: CloudChangeDelegate?
	
	// Should remove these. Currently used to
	// help convert between a CKRecord and a Photo
	var imageStore: ImageStore!
	var photoDataSource: PhotoDataSource!

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
	
	func saveSyncState() {
		
		NSKeyedArchiver.archiveRootObject(syncState, toFile: syncStateArchive)
		print("SyncState saved")
	}
	
	
	func pushNew(photos: [Photo], completion: @escaping (CloudPushResult) -> Void) {
		
		if !ready || photos.isEmpty {
			return
		}
		for photo in photos {
			print("Pushing NEW photo with caption \(photo.caption!)")
		}
		
		let batchSize = photos.count
		let records = photos.map { self.createRecord(from: $0) }
		let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
		
		operation.perRecordCompletionBlock = { (record, error) in
			
			if let error = error {
				print("Error saving photo \(error)")
			}
			
			let recordName = record.recordID.recordName
			let savedPhoto = photos.first { $0.photoID == recordName }
			
			// Set the CKRecord on the photo
			savedPhoto?.ckRecord = self.data(from: record)
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
		
		operation.qualityOfService = .utility
		operation.allowsCellularAccess =
			UserDefaults.standard.bool(forKey: Key.cellSync.rawValue)
		
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
			let rec = record(from: photo.ckRecord!)
			
			rec[photoIDKey] = photo.photoID! as NSString
			
			// Set the only fields that we allow to be changed
			applyChanges(from: photo, to: rec)
			
			records.append(rec)
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
				updatedPhoto?.ckRecord = self.data(from: record)
				
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
			
			// This will give us a record with only
			// the system fields filled in
			let rec = record(from: photo.ckRecord!)
			recordIDs.append(rec.recordID)
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
			UserDefaults.standard.bool(forKey: Key.cellSync.rawValue)
		
		privateDB.add(changeOperation)
	}
	
	// MARK: Functions for converting between NSData and CKRecord
	// (We store only the system fields of the CKRecord)
	func data(from record: CKRecord) -> NSData {
		
		let archivedData = NSMutableData()
		let archiver = NSKeyedArchiver(forWritingWith: archivedData)
		
		archiver.requiresSecureCoding = true
		record.encodeSystemFields(with: archiver)
		archiver.finishEncoding()
		
		return archivedData
	}
	
	func record(from archivedData: NSData) -> CKRecord {
		
		let unarchiver = NSKeyedUnarchiver(forReadingWith: archivedData as Data)
		unarchiver.requiresSecureCoding = true
		
		return CKRecord(coder: unarchiver)!
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
		
			guard let result = self.getPhoto(from: record) else {
				return
			}
			
			print("Fetched photo with caption '\(result.photo.caption!)' and change tag \(record.recordChangeTag!)")
			self.delegate?.didModify(photo: result.photo, withImage: result.image)
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
			UserDefaults.standard.bool(forKey: Key.cellSync.rawValue)
		
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
	
	private func getPhoto(from record: CKRecord) -> FetchResult? {
		
		let photo = self.photoDataSource.allocEmptyPhoto()
		
		photo.caption = record[self.captionKey] as! String?
		photo.dateAdded = record[self.dateAddedKey] as! NSDate?
		photo.dateTaken = record[self.dateTakenKey] as! NSDate?
		photo.lastUpdated = record[self.lastUpdatedKey] as! NSDate?
		photo.photoID = record[self.photoIDKey] as! String?
		photo.ckRecord = data(from: record)
		photo.inCloud = true
		
		// sanity check
		let recIDEqual = record.recordID.recordName == photo.photoID
		assert(recIDEqual)
		
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
	
	private func createRecord(from photo: Photo) -> CKRecord {
		
		// We enforce a unique constraint with our photoID in CloudKit
		// by always creating a record from a CKRecordID with a recordName of photoID
		let recordID = CKRecordID(recordName: photo.photoID!, zoneID: syncState.recordZone!.zoneID)
		let record = CKRecord(recordType: photoType, recordID: recordID)
		
		let imageURL = imageStore.imageURL(forKey: photo.photoID!)
		
		record[captionKey] = photo.caption as NSString?
		record[dateAddedKey] = photo.dateAdded
		record[dateTakenKey] = photo.dateTaken
		record[imageKey] = CKAsset(fileURL: imageURL)
		record[lastUpdatedKey] = photo.lastUpdated
		record[photoIDKey] = photo.photoID as NSString?
		
		return record
	}
	
	private func applyChanges(from photo: Photo, to record: CKRecord) {
		
		assert(record.recordID.recordName == photo.photoID!)
		assert(record[photoIDKey] as! String == photo.photoID!)
		
		// Only apply changes from allowed fields
		record[captionKey] = photo.caption! as CKRecordValue?
		record[lastUpdatedKey] = photo.lastUpdated
	}
	
	// MARK: Dev/testing functions - for sanity checking
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
	
	private func fetchAll(completion: @escaping (CloudFetchResult) -> Void) {
		
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
						
						guard let result = self.getPhoto(from: record) else {
							return
						}
						
						fetchResults.append(result)
					}
				}
			}
		}
	}
}
