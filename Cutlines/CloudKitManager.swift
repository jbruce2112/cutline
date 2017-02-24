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
	
	private var subscribedForChanges = false
	
	let subscriptionID = "private-changes"
	
	private var changeToken: CKServerChangeToken?
	private var changedZoneIDs = [CKRecordZoneID]()
	
	init() {
		
		container = CKContainer.default()
		privateDB = container.privateCloudDatabase
		
		registerForSubscription()
	}
	
	func save(photo: Photo, imageURL: URL, completion: @escaping (CloudResult) -> Void) {
		
		let recordID = CKRecordID(recordName: photo.photoID!)
		let record = CKRecord(recordType: photoType, recordID: recordID)
		return save(photo: photo, imageURL: imageURL, toRecord: record, completion: completion)
	}
	
	func update(photo: Photo, imageURL: URL, completion: @escaping (CloudResult) -> Void) {
		
		let recordID = CKRecordID(recordName: photo.photoID!)
		privateDB.fetch(withRecordID: recordID) { (record, error) in
		
			if let error = error {
				completion(.failure(error))
			} else {
				
				guard let record = record else {
					return
				}
				
				self.save(photo: photo, imageURL: imageURL, toRecord: record, completion: completion)
			}
		}
	}
	
	private func save(photo: Photo, imageURL: URL, toRecord record: CKRecord, completion: @escaping (CloudResult) -> Void) {
		
		record[captionKey] = photo.caption as NSString?
		record[dateAddedKey] = photo.dateAdded
		record[dateTakenKey] = photo.dateTaken
		record[imageKey] = CKAsset(fileURL: imageURL)
		record[lastUpdatedKey] = photo.lastUpdated
		record[photoIDKey] = photo.photoID as NSString?
		
		privateDB.save(record) { (record, error) in
			
			if let error = error {
				print("Photo upload errored \(error)")
				completion(.failure(error))
			} else {
				print("Photo uploaded successfully")
				completion(.success)
			}
		}
	}
	
	func registerForSubscription() {
		
		if subscribedForChanges {
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
				self.subscribedForChanges = true
			}
		}
		
		operation.qualityOfService = .utility
		privateDB.add(operation)
	}
	
	func fetchChanges(completion: @escaping () -> Void) {
		
		changedZoneIDs = []
		
		// When our change token is nil, we'll fetch everything
		let changeOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
		
		changeOperation.fetchAllChanges = true
		changeOperation.recordZoneWithIDChangedBlock = { (recordZoneID) in
			
			self.changedZoneIDs.append(recordZoneID)
		}
		
		changeOperation.changeTokenUpdatedBlock = { (newToken) in
			
			self.changeToken = newToken
		}
		
		changeOperation.fetchDatabaseChangesCompletionBlock = { (newToken, more, error) in
			
			if let error = error {
				print("Got error in fetching changes \(error)")
				return
			}
			
			self.changeToken = newToken
			self.fetchZoneChanges(completion: completion)
		}
		
		privateDB.add(changeOperation)
	}
	
	func fetchZoneChanges(completion: @escaping () -> Void) {
		
		let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: changedZoneIDs)
		
		operation.fetchAllChanges = true
		operation.recordChangedBlock = { (record) in
		
			print("Got record changed with caption \((record[self.captionKey] as! NSString?)!)")
		}
		
		operation.recordWithIDWasDeletedBlock = { (recordID, string) in
		
		}
		
		operation.recordZoneChangeTokensUpdatedBlock = { (recordZoneID, newChangeToken, lastTokenData) in
			
			self.changeToken = newChangeToken
		}
		
		operation.recordZoneFetchCompletionBlock = { (recordZoneID, newChangeToken, lastTokenData, more, error) in
			
			if let error = error {
				print("Got error fetching record changes \(error)")
				return
			}
			
			self.changeToken = newChangeToken
		}
			
		privateDB.add(operation)
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
					
					for result in results {
						
						let photo = (UIApplication.shared.delegate as! AppDelegate).photoDataSource.allocEmptyPhoto()
						
						photo.caption = result[self.captionKey] as! String?
						photo.dateAdded = result[self.dateAddedKey] as! NSDate?
						photo.dateTaken = result[self.dateTakenKey] as! NSDate?
						photo.lastUpdated = result[self.lastUpdatedKey] as! NSDate?
						photo.photoID = result[self.photoIDKey] as! String?
						
						guard let asset = result[self.imageKey] as? CKAsset else {
							return
						}
						
						let imageData: Data
						do {
							imageData = try Data(contentsOf: asset.fileURL)
						} catch {
							return
						}
						
						var fetchResult = FetchResult()
						fetchResult.photo = photo
						fetchResult.image = UIImage(data: imageData)
						fetchResults.append(fetchResult)
					}
				}
			}
		}
	}
}
