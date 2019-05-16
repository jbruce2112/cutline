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

/// Tuple to bind a Photo with an image URL
typealias PhotoPair = (photo: Photo, url: URL)

/// A simple container type to bridge between
/// a Photo (NSObjectModel) type and a CKRecord.
/// This allows the model to represent Photos
/// without needing to allocate an empty CoreData object.
struct CloudPhoto {
	
	// MARK: Properties
	var id: String
	var lastUpdated: Date
	var dateTaken: Date
	var dateAdded: Date
	var ckRecord: Data?
	var caption: String
	
	var image: Data?
	var imageAsset: CKAsset?
		
	static let captionKey = "caption"
	static let dateAddedKey = "dateAdded"
	static let dateTakenKey = "dateTaken"
	static let imageKey = "image"
	static let lastUpdatedKey = "lastUpdated"
	static let idKey = "id"
		
	init?(fromPair pair: PhotoPair) {
		
		guard
			let caption = pair.photo.caption,
			let dateAdded = pair.photo.dateAdded,
			let dateTaken = pair.photo.dateTaken,
			let lastUpdated = pair.photo.lastUpdated,
			let id = pair.photo.id else {
				return nil
		}
		
		self.caption = caption
		self.dateAdded = dateAdded
		self.dateTaken = dateTaken
		self.lastUpdated = lastUpdated
		self.id = id
		
		if let record = pair.photo.ckRecord {
			self.ckRecord = record
		}
		self.imageAsset = CKAsset(fileURL: pair.url)
	}
	
	init?(fromRecord record: CKRecord) {
	
		guard
			let caption = record[CloudPhoto.captionKey] as? String,
			let dateAdded = record[CloudPhoto.dateAddedKey] as? Date,
			let dateTaken = record[CloudPhoto.dateTakenKey] as? Date,
			let lastUpdated = record[CloudPhoto.lastUpdatedKey] as? Date,
			let id = record[CloudPhoto.idKey] as? String else {
				return nil
		}
		
		self.id = id
		self.caption = caption
		self.dateAdded = dateAdded
		self.dateTaken = dateTaken
		self.lastUpdated = lastUpdated
		self.ckRecord = CloudPhoto.systemData(fromRecord: record)
		
		// sanity check
		assert(record.recordID.recordName == id)
		
		guard let asset = record[CloudPhoto.imageKey] as? CKAsset,
			let fileURL = asset.fileURL else {
				log("Unable to get CKAsset from record")
				return nil
		}
		
		// The client converted this to a JPEG before uploading.
		image = try? Data(contentsOf: fileURL)
		
		if image == nil {
			log("Unable to get JPEG from Data")
			return nil
		}
	}
	
	// MARK: Static functions for converting between NSData and CKRecord
	// (We store only the system fields of the CKRecord)
	static func systemData(fromRecord record: CKRecord) -> Data {
		
		let archivedData = NSMutableData()
		let archiver = NSKeyedArchiver(forWritingWith: archivedData)
		
		archiver.requiresSecureCoding = true
		record.encodeSystemFields(with: archiver)
		archiver.finishEncoding()
		
		return archivedData as Data
	}
	
	static func systemRecord(fromData archivedData: Data) -> CKRecord {
		
		let unarchiver = NSKeyedUnarchiver(forReadingWith: archivedData)
		unarchiver.requiresSecureCoding = true
		
		return CKRecord(coder: unarchiver)!
	}
	
    static func createRecord(fromPair pair: PhotoPair, withZoneID zoneID: CKRecordZone.ID) -> CKRecord? {
		
		guard let photo = CloudPhoto(fromPair: pair) else {
			return nil
		}
		
		// We enforce a unique constraint with our photoID in CloudKit
		// by always creating a record from a CKRecordID with a recordName of photoID
        let recordID = CKRecord.ID(recordName: photo.id, zoneID: zoneID)
		let record = CKRecord(recordType: "Photo", recordID: recordID)
		
		record[CloudPhoto.captionKey] = photo.caption as NSString
		record[CloudPhoto.dateAddedKey] = photo.dateAdded as NSDate
		record[CloudPhoto.dateTakenKey] = photo.dateTaken as NSDate
		record[CloudPhoto.imageKey] = photo.imageAsset
		record[CloudPhoto.lastUpdatedKey] = photo.lastUpdated as NSDate
		record[CloudPhoto.idKey] = photo.id as NSString
		
		return record
	}
}
