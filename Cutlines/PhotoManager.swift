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
	
	func didAdd(photo: Photo)
	func didRemove(photoID: String)
}

class PhotoManager {
	
	// MARK: Properties
	var cloudManager: CloudKitManager!
	var photoDataSource: PhotoDataSource!
	var imageStore: ImageStore!
	
	weak var delegate: PhotoChangeDelegate?
	
	// MARK: Functions
	func setup() {
		
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
	
	func add(image: UIImage, caption: String, dateTaken: Date, completion: ((PhotoUpdateResult) -> Void)?) {
		
		let id = NSUUID().uuidString
		imageStore.setImage(image, forKey: id)
		
		photoDataSource.addPhoto(id: id, caption: caption, dateTaken: dateTaken) { result in
			
			switch result {
			case let .success(photo):
				
				self.delegate?.didAdd(photo: photo!)
				
				self.cloudManager.pushNew(photos: [photo!]) { cloudResult in
					
					// TODO: error handling
					switch cloudResult {
					case .success:
						// Save the CKRecord that the photo now has
						self.photoDataSource.save()
						completion?(.success)
					case let .failure(error):
						completion?(.failure(error))
					}
				}
			case let .failure(error):
				print("Cutline save failed with error: \(error)")
			}
		}
	}
	
	func update(photo: Photo, completion: ((PhotoUpdateResult) -> Void)?) {
		
		photo.dirty = true
		photoDataSource.save()
		print("photo marked dirty")
		
		cloudManager.pushModified(photos: [photo]) { cloudResult in
			
			// TODO: error handling
			switch cloudResult {
			case .success:
				
				photo.dirty = false
				self.photoDataSource.save()
				print("photo un-marked dirty")
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
		photoDataSource.save()
		self.delegate?.didRemove(photoID: photo.photoID!)
		
		self.cloudManager.delete(photos: [photo]) { cloudResult in
			
			// TODO: error handling
			switch cloudResult {
			case .success:
				
				let photoID = photo.photoID!
				self.photoDataSource.delete(photoWithID: photoID) { localResult in
					
					switch localResult {
					case .success:
						
						self.imageStore.deleteImage(forKey: photoID)
						print("Photo deleted locally")
						completion?(.success)
					case let .failure(error):
						print("Photo delete failed locally \(error)")
						completion?(.failure(error))
					}
				}
			case let .failure(error):
				print("Error deleting photo from cloud \(error)")
				completion?(.failure(error))
			}
		}
	}
	
	func image(for photo: Photo) -> UIImage? {
		
		guard let photoID = photo.photoID else {
			return nil
		}
		
		return imageStore.image(forKey: photoID)
	}
	
	// MARK: Private functions
	private func pushNewLocalPhotos(batchSize: Int = 5) {
		
		let localPhotos = photoDataSource.fetchOnlyLocal(limit: batchSize)
		
		if localPhotos.isEmpty {
			return
		}
		
		cloudManager.pushNew(photos: localPhotos) { result in
			
			// TODO: error handling
			switch result {
			case .success:
				
				// Save the CKRecords that were added to the photos
				self.photoDataSource.save()
				
				// Push another batch
				self.pushNewLocalPhotos(batchSize: batchSize)
				
			case let .failure(error):
				print("Not pushing any more photos due to error \(error)")
			}
		}
	}
	
	private func pushModifiedPhotos(batchSize: Int = 5) {
		
		let modifiedPhotos = photoDataSource.fetchModified(limit: batchSize)
		
		if modifiedPhotos.isEmpty {
			return
		}
		
		cloudManager.pushModified(photos: modifiedPhotos) { result in
			
			// TODO: error handling
			switch result {
			case .success:
				
				// Save the updated CKRecords that were added to the photos
				self.photoDataSource.save()
				
				// Push another batch
				self.pushModifiedPhotos(batchSize: batchSize)
				
			case let .failure(error):
				print("Not pushing any more photos due to error \(error)")
			}
		}
	}
	
	private func pushDeletedPhotos() {
		
		let deletedPhotos = photoDataSource.fetchDeleted(limit: nil)
		
		if deletedPhotos.isEmpty {
			return
		}
		
		cloudManager.delete(photos: deletedPhotos) { result in
			
			// TODO: error handling
			switch result {
			case .success:
				
				self.photoDataSource.delete(photos: deletedPhotos) { result in
					switch result {
					case .success:
						break
					case let .failure(error):
						print("Error deleting photos from dataSource \(error)")
					}
				}
			case let .failure(error):
				print("Not pushing any more photos due to error \(error)")
			}
		}
	}
}

// MARK: CloudChangeDelegate conformance
extension PhotoManager: CloudChangeDelegate {
	
	func didModify(photo modifiedPhoto: Photo, withImage image: UIImage) {
		
		let existingPhoto = photoDataSource.fetch(withID: modifiedPhoto.photoID!)
		
		if existingPhoto == nil {
			
			// We got a new photo from the cloud
			self.photoDataSource.addPhoto(modifiedPhoto) { result in
				
				switch result {
				case .success:
					
					self.imageStore.setImage(image, forKey: modifiedPhoto.photoID!)
					print("New photo added with caption '\(modifiedPhoto.caption!)'")
					self.delegate?.didAdd(photo: modifiedPhoto)
				case let .failure(error):
					
					print("Error saving photo \(error)")
				}
			}
		} else {
			
			assert(existingPhoto!.ckRecord != nil)
			
			let cloudRecord = cloudManager.record(from: modifiedPhoto.ckRecord!)
			let localRecord = cloudManager.record(from: existingPhoto!.ckRecord!)
			
			if localRecord.recordID == cloudRecord.recordID &&
				localRecord.recordChangeTag == cloudRecord.recordChangeTag &&
				localRecord.modificationDate == cloudRecord.modificationDate {
				
				// This is expected behavior the first time our device asks
				// for changes after adding a new photo. CloudKit does not provide
				// a serverChangeToken after we push changes (adds or deletes),
				// so we just have to no-op this. Since we're in this scenerio
				// because we asked for changes, out token should be up to date now.
				print("Got an update for a change we already have")
				return
			}
			
			// We got an update for an existing photo, save the changes
			existingPhoto!.lastUpdated = modifiedPhoto.lastUpdated
			existingPhoto!.caption = modifiedPhoto.caption
			existingPhoto!.ckRecord = modifiedPhoto.ckRecord
			
			self.photoDataSource.save()
			
			print("Existing photo updated with new caption '\((existingPhoto?.caption)!)'")
		}
	}
	
	func didRemove(photoID: String) {
		
		let existingPhoto = photoDataSource.fetch(withID: photoID)
		
		if existingPhoto == nil {
			// Already gone
			// This is expected behavior the first time our device asks
			// for changes after deleting a photo. CloudKit does not provide
			// a serverChangeToken after we push changes (adds or deletes),
			// so we just have to no-op this. Since we're in this scenerio
			// because we asked for changes, our token should be up to date now.
			print("Fetched a delete for a photo we don't have")
			return
		}
		
		photoDataSource.delete(photoWithID: photoID) { result in
			
			switch result {
			case .success:
				
				self.imageStore.deleteImage(forKey: photoID)
				print("Deleted photo with id '\(photoID)'")
				self.delegate?.didRemove(photoID: photoID)
			case let .failure(error):
				
				print("Error deleting photo \(error)")
			}
		}
	}
}
