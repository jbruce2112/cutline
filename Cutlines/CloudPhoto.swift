//
//  CloudPhoto.swift
//  Cutlines
//
//  Created by John on 3/2/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import CloudKit
import Foundation
import UIKit

// A simple container type to bridge between
// a Photo (NSObjectModel) type and a CKRecord.
// This gives the model layer more flexibility
// in creating Photo objects without needing
// to allocate an empty CoreData object.
//
// Multiple ways to init are provided to allow
// both the PhotoManager and CloudKitManager
// to create and and populate this type for use.
class CloudPhoto {
	
	// MARK: Properties
	var photoID: String!
	var lastUpdated: NSDate!
	var dateTaken: NSDate!
	var dateAdded: NSDate!
	var ckRecord: NSData?
	var caption: String!
	
	var image: UIImage?
	var imageAsset: CKAsset?
		
	private static let captionKey = "caption"
	private static let dateAddedKey = "dateAdded"
	private static let dateTakenKey = "dateTaken"
	private static let imageKey = "image"
	private static let lastUpdatedKey = "lastUpdated"
	private static let photoIDKey = "photoID"
	
	init() {
	}
	
	init(from photo: Photo, imageURL: URL) {
		
		caption = photo.caption!
		dateAdded = photo.dateAdded!
		dateTaken = photo.dateTaken!
		lastUpdated = photo.lastUpdated!
		photoID = photo.photoID!
		ckRecord = photo.ckRecord
		imageAsset = CKAsset(fileURL: imageURL)
	}
	
	init?(fromRecord record: CKRecord) {
	
		caption = record[CloudPhoto.captionKey] as! String
		dateAdded = record[CloudPhoto.dateAddedKey] as! NSDate
		dateTaken = record[CloudPhoto.dateTakenKey] as! NSDate
		lastUpdated = record[CloudPhoto.lastUpdatedKey] as! NSDate
		photoID = record[CloudPhoto.photoIDKey] as! String
		ckRecord = CloudPhoto.systemData(fromRecord: record)
		
		// sanity check
		assert(record.recordID.recordName == photoID)
		
		guard let asset = record[CloudPhoto.imageKey] as? CKAsset else {
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
		
		image = UIImage(data: imageData)
		
		if image == nil {
			print("Unable to get UIImage from Data")
			return nil
		}
	}
	
	func getRecord(withZoneID zoneID: CKRecordZoneID) -> CKRecord {
		
		// We enforce a unique constraint with our photoID in CloudKit
		// by always creating a record from a CKRecordID with a recordName of photoID
		let recordID = CKRecordID(recordName: photoID!, zoneID: zoneID)
		let record = CKRecord(recordType: "Photo", recordID: recordID)
		
		record[CloudPhoto.captionKey] = caption as NSString?
		record[CloudPhoto.dateAddedKey] = dateAdded
		record[CloudPhoto.dateTakenKey] = dateTaken
		record[CloudPhoto.imageKey] = imageAsset
		record[CloudPhoto.lastUpdatedKey] = lastUpdated
		record[CloudPhoto.photoIDKey] = photoID as NSString?
		
		return record
	}
	
	// MARK: Static functions for converting between NSData and CKRecord
	// (We store only the system fields of the CKRecord)
	static func systemData(fromRecord record: CKRecord) -> NSData {
		
		let archivedData = NSMutableData()
		let archiver = NSKeyedArchiver(forWritingWith: archivedData)
		
		archiver.requiresSecureCoding = true
		record.encodeSystemFields(with: archiver)
		archiver.finishEncoding()
		
		return archivedData
	}
	
	static func systemRecord(fromData archivedData: NSData) -> CKRecord {
		
		let unarchiver = NSKeyedUnarchiver(forReadingWith: archivedData as Data)
		unarchiver.requiresSecureCoding = true
		
		return CKRecord(coder: unarchiver)!
	}
	
	static func applyChanges(from photo: Photo, to record: CKRecord) {
		
		// Only apply changes from allowed fields
		record[captionKey] = photo.caption! as CKRecordValue?
		record[lastUpdatedKey] = photo.lastUpdated
	}
}
