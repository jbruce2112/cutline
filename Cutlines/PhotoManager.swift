//
//  PhotoManager.swift
//  Cutlines
//
//  Created by John on 2/25/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import Foundation
import UIKit

class PhotoManager {
	
	// MARK: Properties
	var cloudManager: CloudKitManager!
	var photoDataSource: PhotoDataSource!
	var imageStore: ImageStore!
	
	// MARK: Functions
	func setup(completion: @escaping () -> Void) {
		
		cloudManager.setup {
			
			// Once we're set up, fetch any
			// changes, and then push up any
			// remaining photos
			self.cloudManager.fetchChanges {
				
				completion()
				
				self.pushNewLocalPhotos()
				// TODO: Push up modified photos
			}
		}
	}
	
	func add(image: UIImage, caption: String, dateTaken: Date, completion: (() -> Void)?) {
		
		let id = NSUUID().uuidString
		imageStore.setImage(image, forKey: id)
		
		photoDataSource.addPhoto(id: id, caption: caption, dateTaken: dateTaken) { result in
			
			switch result {
			case let .success(photo):
				
				self.cloudManager.pushNew(photos: [photo!]) { cloudResult in
					
					// TODO: error handling
					switch cloudResult {
					case .success:
						// The photo has a CKRecord now, save it
						self.photoDataSource.save()
					case .failure:
						break
					}
					
					completion?()					
				}
			case let .failure(error):
				print("Cutline save failed with error: \(error)")
			}
		}
	}
	
	func update(photo: Photo, completion: (() -> Void)?) {
		
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
			case .failure:
				break
			}
		}
	}
	
	func delete(photo: Photo, completion: (() -> Void)?) {
		
		photoDataSource.delete(photo: photo) { result in
			
			switch result {
			case .success:
				print("Photo deleted locally")
			case let .failure(error):
				print("Photo delete failed locally \(error)")
			}
		}
		
		cloudManager.delete(photos: [photo]) { cloudResult in
			
			// TODO: error handling
			switch cloudResult {
			case .success:
				break
			case .failure:
				break
			}
		}
	}
	
	func image(for photo: Photo) -> UIImage? {
		
		return imageStore.image(forKey: photo.photoID!)
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
				
				// Push another batch
				self.pushNewLocalPhotos()
				
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
				case let .failure(error):
					
					print("Error saving photo \(error)")
				}
			}
		} else {
			
			// We got an update for an existing photo, save the changes
			existingPhoto?.lastUpdated = modifiedPhoto.lastUpdated
			existingPhoto?.caption = modifiedPhoto.caption
			existingPhoto?.ckRecord = modifiedPhoto.ckRecord
			
			self.photoDataSource.save()
			
			print("Existing photo updated with new caption '\(existingPhoto?.caption!)'")
		}
	}
	
	func didRemove(photoID: String) {
	}
}
