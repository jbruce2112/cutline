//
//  PhotoManager.swift
//  Cutlines
//
//  Created by John on 2/25/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import Foundation
import UIKit

enum PhotoUpdateResult {
	case success
	case failure(Error)
}

// MARK: PhotoChangeDelegate
protocol PhotoChangeDelegate: class {
	
	func didAdd()
	func didRemove()
}

class PhotoManager {
	
	// MARK: Properties
	var cloudManager = CloudKitManager()
	var photoStore = PhotoStore()
	var imageStore = ImageStore()
	
	weak var delegate: PhotoChangeDelegate?
	
	// MARK: Functions
	func setup() {
		
		cloudManager.delegate = self
		
		cloudManager.setup {
			
			// Once we're set up, fetch any
			// changes, and then push up any
			// changes of our own
			self.cloudManager.fetchChanges {
				
				self.pushDeletedPhotos()
				self.pushModifiedPhotos()
				self.pushNewLocalPhotos()
			}
		}
	}
	
	func setupNoSync(completion: @escaping () -> Void) {
		
		cloudManager.setupNoSync {
			
			completion()
		}
	}
	
	func add(image: UIImage, caption: String, dateTaken: Date, qos: QualityOfService?, completion: ((PhotoUpdateResult) -> Void)?) {
		
		let id = NSUUID().uuidString
		imageStore.setImage(image, forKey: id)
		
		photoStore.add(id: id, caption: caption, dateTaken: dateTaken) { result in
			
			switch result {
			case let .success(photo):
				
				self.delegate?.didAdd()
				
				// Bind the Photo and Image for the add
				let imageURL = self.imageStore.imageURL(forKey: id)
				let photoPair = (photo: photo!, url: imageURL)
				
				self.cloudManager.pushNew(pairs: [photoPair], qos: qos) { cloudResult in
					
					// TODO: error handling
					switch cloudResult {
					case .success:
						// Save the CKRecord that the photo now has
						self.photoStore.save()
						completion?(.success)
					case let .failure(error):
						completion?(.failure(error))
					}
				}
			case let .failure(error):
				Log("Cutline save failed with error: \(error)")
			}
		}
	}
	
	func update(photo: Photo, completion: ((PhotoUpdateResult) -> Void)?) {
		
		photo.dirty = true
		photoStore.save()
		Log("photo marked dirty")
		
		cloudManager.pushModified(photos: [photo]) { cloudResult in
			
			// TODO: error handling
			switch cloudResult {
			case .success:
				
				photo.dirty = false
				self.photoStore.save()
				Log("photo un-marked dirty")
				completion?(.success)
			case let .failure(error):
				completion?(.failure(error))
			}
		}
	}
	
	func delete(photo: Photo, completion: ((PhotoUpdateResult) -> Void)?) {
		
		// Mark this photo deleted locally before we
		// attempt the cloud call, so we can filter it out
		// of our collection view right away
		photo.markedDeleted = true
		photoStore.save()
		
		self.delegate?.didRemove()
		
		self.cloudManager.delete(photos: [photo]) { cloudResult in
			
			// TODO: error handling
			switch cloudResult {
			case .success:
				
				let photoID = photo.id!
				self.photoStore.delete(withID: photoID) { localResult in
					
					switch localResult {
					case .success:
						
						self.imageStore.deleteImage(forKey: photoID) {
							Log("Photo deleted locally")
							completion?(.success)
						}
					case let .failure(error):
						Log("Photo delete failed locally \(error)")
						completion?(.failure(error))
					}
				}
			case let .failure(error):
				Log("Error deleting photo from cloud \(error)")
				completion?(.failure(error))
			}
		}
	}
	
	func image(for photo: Photo, completion: @escaping (UIImage?) -> Void) {
		
		guard let photoID = photo.id else {
			completion(nil)
			return
		}
		
		imageStore.image(forKey: photoID) { image in
			
			DispatchQueue.main.async {
				completion(image)
			}
		}
	}
	
	func thumbnail(for photo: Photo, withSize size: CGSize, completion: @escaping (UIImage?) -> Void) {
		
		guard let photoID = photo.id else {
			
			DispatchQueue.main.async {
				completion(nil)
			}
			return
		}
		
		imageStore.thumbnail(forKey: photoID, size: size) { image in
			
			DispatchQueue.main.async {
				completion(image)
			}
		}
	}
	
	// MARK: Private functions
	private func pushNewLocalPhotos(batchSize: Int = 5) {
		
		let localPhotos = photoStore.fetchOnlyLocal(limit: batchSize)
		
		if localPhotos.isEmpty {
			return
		}
		
		let photoPairs = localPhotos.map {
			
			(photo: $0, url: imageStore.imageURL(forKey: $0.id!))
		}
		
		cloudManager.pushNew(pairs: photoPairs, qos: nil) { result in
			
			// TODO: error handling
			switch result {
			case .success:
				
				// Save the CKRecords that were added to the photos
				self.photoStore.save()
				
				// Push another batch
				self.pushNewLocalPhotos(batchSize: batchSize)
				
			case let .failure(error):
				Log("Not pushing any more photos due to error \(error)")
			}
		}
	}
	
	private func pushModifiedPhotos(batchSize: Int = 5) {
		
		let modifiedPhotos = photoStore.fetchModified(limit: batchSize)
		
		if modifiedPhotos.isEmpty {
			return
		}
		
		cloudManager.pushModified(photos: modifiedPhotos) { result in
			
			// TODO: error handling
			switch result {
			case .success:
				
				// Mark un-dirty and save the updated CKRecords added to the photos
				modifiedPhotos.forEach { $0.dirty = false }
				self.photoStore.save()
				
				// Push another batch
				self.pushModifiedPhotos(batchSize: batchSize)
				
			case let .failure(error):
				Log("Not pushing any more photos due to error \(error)")
			}
		}
	}
	
	private func pushDeletedPhotos() {
		
		let deletedPhotos = photoStore.fetchDeleted(limit: nil)
		
		if deletedPhotos.isEmpty {
			return
		}
		
		cloudManager.delete(photos: deletedPhotos) { cloudResult in
			
			// TODO: error handling
			switch cloudResult {
			case .success:
				
				// Only truly delete the photolocally
				// once we know the cloud got the delete
				self.photoStore.delete(photos: deletedPhotos) { result in
					switch result {
					case .success:
						break
					case let .failure(error):
						Log("Error deleting photos from dataSource \(error)")
					}
				}
			case let .failure(error):
				Log("Not pushing any more photos due to error \(error)")
			}
		}
	}
}

// MARK: CloudChangeDelegate conformance
extension PhotoManager: CloudChangeDelegate {
	
	func didModify(photo: CloudPhoto) {
		
		let existingPhoto = photoStore.fetch(withID: photo.id)
		
		if existingPhoto == nil {
			
			// We got a new photo from the cloud
			self.photoStore.add(photo) { result in
				
				switch result {
				case .success:
					
					DispatchQueue.global().async {
						
						self.imageStore.setImage(photo.image!, forKey: photo.id)
						Log("New photo added with caption '\(photo.caption!)'")
						self.delegate?.didAdd()
					}
				case let .failure(error):
					
					Log("Error saving photo \(error)")
				}
			}
		} else {
			
			// It's technically possible for us to have added a photo locally,
			// told the cloud about it, and then exited before we were able to
			// add the record to our local store. We should just save the
			// current version from the cloud when this happens.
			
			if let existingRecord = existingPhoto!.ckRecord {
				
				let localRecord = CloudPhoto.systemRecord(fromData: existingRecord)
				let cloudRecord = CloudPhoto.systemRecord(fromData: photo.ckRecord!)
				
				if localRecord.recordID == cloudRecord.recordID &&
					localRecord.recordChangeTag == cloudRecord.recordChangeTag &&
					localRecord.modificationDate == cloudRecord.modificationDate {
					
					// This is expected behavior the first time our device asks
					// for changes after adding a new photo. CloudKit does not provide
					// a serverChangeToken after we push changes (adds or deletes),
					// so we just have to no-op this. Since we're in this scenerio
					// because we asked for changes, out token should be up to date now.
					Log("Got an update for a change we already have")
					return
				}
			}
			
			// We got an update for an existing photo, save the changes
			existingPhoto!.lastUpdated = photo.lastUpdated
			existingPhoto!.caption = photo.caption
			existingPhoto!.ckRecord = photo.ckRecord
			
			self.photoStore.save()
			
			Log("Existing photo updated with new caption '\((existingPhoto?.caption)!)'")
		}
	}
	
	func didRemove(photoID: String) {
		
		let existingPhoto = photoStore.fetch(withID: photoID)
		
		if existingPhoto == nil {
			// Already gone
			// This is expected behavior the first time our device asks
			// for changes after deleting a photo. CloudKit does not provide
			// a serverChangeToken after we push changes (adds or deletes),
			// so we just have to no-op this. Since we're in this scenerio
			// because we asked for changes, our token should be up to date now.
			Log("Fetched a delete for a photo we don't have")
			return
		}
		
		photoStore.delete(withID: photoID) { result in
			
			switch result {
			case .success:
				
				self.imageStore.deleteImage(forKey: photoID) {
					
					Log("Deleted photo with id '\(photoID)'")
					self.delegate?.didRemove()
				}
			case let .failure(error):
				
				Log("Error deleting photo \(error)")
			}
		}
	}
}
