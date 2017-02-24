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
	
	init() {
		
		container = CKContainer.default()
		privateDB = container.privateCloudDatabase
	}
	
	func save(photo: Photo, imageURL: URL, completion: @escaping (CloudResult) -> Void) {
		
		let recordID = CKRecordID(recordName: photo.photoID!)
		let record = CKRecord(recordType: photoType, recordID: recordID)
		
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
