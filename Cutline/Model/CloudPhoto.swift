//
//  CloudPhoto.swift
//  Cutline
//
//  Created by John on 3/2/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import CloudKit
import Foundation
import UIKit

// Tuple to bind a Photo with an image URL
typealias PhotoPair = (photo: Photo, url: URL)

// A simple container type to bridge between
// a Photo (NSObjectModel) type and a CKRecord.
// This allows the model to represent Photos
// without needing to allocate an empty CoreData object.
struct CloudPhoto {
	
	// MARK: Properties
	var id: String
	var lastUpdated: NSDate
	var dateTaken: NSDate
	var dateAdded: NSDate
	var ckRecord: NSData?
	var caption: String
	
	var image: Data?
	var imageAsset: CKAsset?
		
	static let captionKey = "caption"
	static let dateAddedKey = "dateAdded"
	static let dateTakenKey = "dateTaken"
	static let imageKey = "image"
	static let lastUpdatedKey = "lastUpdated"
	static let idKey = "id"
		
	init(fromPair pair: PhotoPair) {
		
		caption = pair.photo.caption!
		dateAdded = pair.photo.dateAdded!
		dateTaken = pair.photo.dateTaken!
		lastUpdated = pair.photo.lastUpdated!
		id = pair.photo.id!
		ckRecord = pair.photo.ckRecord
		imageAsset = CKAsset(fileURL: pair.url)
	}
	
	init?(fromRecord record: CKRecord) {
	
		caption = record[CloudPhoto.captionKey] as! String
		dateAdded = record[CloudPhoto.dateAddedKey] as! NSDate
		dateTaken = record[CloudPhoto.dateTakenKey] as! NSDate
		lastUpdated = record[CloudPhoto.lastUpdatedKey] as! NSDate
		id = record[CloudPhoto.idKey] as! String
		ckRecord = CloudPhoto.systemData(fromRecord: record)
		
		// sanity check
		assert(record.recordID.recordName == id)
		
		guard let asset = record[CloudPhoto.imageKey] as? CKAsset else {
			log("Unable to get CKAsset from record")
			return nil
		}
		
		// The client converted this to a JPEG before uploading.
		image = try? Data(contentsOf: asset.fileURL)
		
		if image == nil {
			log("Unable to get JPEG from Data")
			return nil
		}
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
	
	static func createRecord(fromPair pair: PhotoPair, withZoneID zoneID: CKRecordZoneID) -> CKRecord {
		
		let photo = CloudPhoto(fromPair: pair)
		
		// We enforce a unique constraint with our photoID in CloudKit
		// by always creating a record from a CKRecordID with a recordName of photoID
		let recordID = CKRecordID(recordName: photo.id, zoneID: zoneID)
		let record = CKRecord(recordType: "Photo", recordID: recordID)
		
		record[CloudPhoto.captionKey] = photo.caption as NSString
		record[CloudPhoto.dateAddedKey] = photo.dateAdded
		record[CloudPhoto.dateTakenKey] = photo.dateTaken
		record[CloudPhoto.imageKey] = photo.imageAsset
		record[CloudPhoto.lastUpdatedKey] = photo.lastUpdated
		record[CloudPhoto.idKey] = photo.id as NSString
		
		return record
	}
}
