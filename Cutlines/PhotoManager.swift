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
				
				self.pushLocalPhotos()
			}
		}
	}
	
	func add(image: UIImage, caption: String, dateTaken: Date, completion: @escaping () -> Void) {
		
		let id = NSUUID().uuidString
		imageStore.setImage(image, forKey: id)
		
		photoDataSource.addPhoto(id: id, caption: caption, dateTaken: dateTaken) { (result) in
			
			switch result {
			case let .success(photo):
				
				self.cloudManager.pushChanges(localPhotos: [photo!]) { cloudResult in
					
					// TODO: error handling
					switch cloudResult {
					case .success:
						break
					case .failure:
						break
					}
				}
			case let .failure(error):
				print("Cutline save failed with error: \(error)")
			}
		}
	}
	
	func update(photo: Photo, completion: @escaping () -> Void) {
		
	}
	
	func image(for photo: Photo) -> UIImage? {
		
		return imageStore.image(forKey: photo.photoID!)
	}
	
	// MARK: Private functions
	private func pushLocalPhotos(batchSize: Int = 5) {
		
		let localPhotos = photoDataSource.fetchOnlyLocal(limit: batchSize)
		
		if localPhotos.isEmpty {
			return
		}
		
		cloudManager.pushChanges(localPhotos: localPhotos) { result in
			
			// TODO: error handling
			switch result {
			case .success:
				
				// Push another batch
				self.pushLocalPhotos()
				
			case let .failure(error):
				print("Not pushing any more photos due to error \(error)")
			}
		}
	}
}

// MARK: CloudChangeDelegate conformance
extension PhotoManager: CloudChangeDelegate {
	
	func didAdd(photo: Photo, withImage image: UIImage) {
		
		self.photoDataSource.addPhoto(photo) { result in
			
			switch result {
			case .success:
				
				self.imageStore.setImage(image, forKey: photo.photoID!)
			case let .failure(error):
				
				print("Error saving photo \(error)")
			}
		}
	}
	
	func didUpdate(photo: Photo) {
	}
	
	func didRemove(photoID: String) {
	}
}
