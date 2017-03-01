//
//  PhotoDataSource.swift
//  Cutlines
//
//  Created by John Bruce on 1/31/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit
import CoreData

enum UpdateResult {
	
	case success(Photo?)
	case failure(Error)
}

class PhotoDataSource: NSObject {
	
	// MARK: Properties
	var photos = [Photo]()
	
	private let entityName = "Photo"
	
	private let persistantContainer: NSPersistentContainer = {
		
		let container = NSPersistentContainer(name: "Cutlines")
		container.loadPersistentStores { (_, error) in
			
			if let error = error {
				print("Error setting up Core Data \(error)")
			}
		}
		return container
	}()
	
	// MARK: Functions
	func refresh(completion: @escaping (UpdateResult) -> Void) {
		
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		
		let sortByDateAdded = NSSortDescriptor(key: #keyPath(Photo.dateAdded), ascending: true)
		fetchRequest.sortDescriptors = [sortByDateAdded]
		
		// Filter out those that are marked for deletion
		fetchRequest.predicate = NSPredicate(format: "\(#keyPath(Photo.markedDeleted)) == NO")
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			do {
				try self.photos = viewContext.fetch(fetchRequest)
				completion(.success(nil))
			} catch {
				completion(.failure(error))
			}
		}
	}
	
	func fetchOnlyLocal(limit: Int?) -> [Photo] {
		
		let predicate = NSPredicate(format: "\(#keyPath(Photo.ckRecord)) == nil")
		return fetch(withPredicate: predicate, limit: limit)
	}
	
	func fetchModified(limit: Int?) -> [Photo] {
		
		let predicate = NSPredicate(format: "\(#keyPath(Photo.dirty)) == YES")
		return fetch(withPredicate: predicate, limit: limit)
	}
	
	func fetchDeleted(limit: Int?) -> [Photo] {
		
		let predicate = NSPredicate(format: "\(#keyPath(Photo.markedDeleted)) == YES")
		return fetch(withPredicate: predicate, limit: limit)
	}
	
	func fetch(withID id: String) -> Photo? {
		
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "\(#keyPath(Photo.photoID)) == %@", id)
		
		var result = [Photo]()
		let viewContext = persistantContainer.viewContext
		viewContext.performAndWait {
			
			do {
				try result = viewContext.fetch(fetchRequest)
			} catch {
				print("Error fetching local photos \(error)")
			}
		}
		
		return result.first
	}
	
	func addPhoto(id: String, caption: String, dateTaken: Date, completion: @escaping (UpdateResult) -> Void) {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			assert(caption != captionPlaceholder)
			
			let entityDescription = NSEntityDescription.entity(forEntityName: self.entityName, in: viewContext)
			let photo = NSManagedObject(entity: entityDescription!, insertInto: viewContext) as! Photo
			photo.photoID = id
			photo.caption = caption
			photo.dateTaken = dateTaken as NSDate
			photo.dateAdded = NSDate()
			photo.lastUpdated = NSDate()
			
			viewContext.insert(photo)
			
			do {
				try viewContext.save()
				completion(.success(photo))
			} catch {
				viewContext.rollback()
				completion(.failure(error))
			}
		}
	}
	
	func addPhoto(_ photo: Photo, completion: @escaping (UpdateResult) -> Void) {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			viewContext.insert(photo)
			
			do {
				try viewContext.save()
				completion(.success(photo))
			} catch {
				viewContext.rollback()
				completion(.failure(error))
			}
		}
	}
	
	func delete(photoWithID id: String, completion: @escaping (UpdateResult) -> Void) {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			guard let photo = self.fetch(withID: id) else {
				print("Photo not deleted from CoreData because we couldn't find it")
				// Still successful even if we didn't have the photo
				completion(.success(nil))
				return
			}
			
			viewContext.delete(photo)
			
			do {
				try viewContext.save()
				completion(.success(nil))
			} catch {
				completion(.failure(error))
			}
		}
	}
	
	func delete(photos: [Photo], completion: ((UpdateResult) -> Void)?) {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			for photo in photos {
				viewContext.delete(photo)
			}
			
			do {
				try viewContext.save()
				completion?(.success(nil))
			} catch {
				completion?(.failure(error))
			}
		}
	}
	
	// Expose the CoreData Photo type for others
	// to populate and pass around before saving (e.g. CloudManager)
	func allocEmptyPhoto() -> Photo {
		
		let entity = persistantContainer.managedObjectModel.entitiesByName[entityName]
		return NSManagedObject(entity: entity!, insertInto: nil) as! Photo
	}
	
	func save() {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			do {
				try viewContext.save()
			} catch {
				viewContext.rollback()
				print("Error saving context \(error)")
			}
		}
	}
	
	private func fetch(withPredicate predicate: NSPredicate, limit: Int?) -> [Photo] {
		
		var localPhotos = [Photo]()
		
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		fetchRequest.predicate = predicate
		
		if let limit = limit {
			fetchRequest.fetchLimit = limit
		}
		
		let viewContext = persistantContainer.viewContext
		viewContext.performAndWait {
			
			do {
				try localPhotos = viewContext.fetch(fetchRequest)
			} catch {
				print("Error fetching photos \(error)")
			}
		}
		
		return localPhotos
	}
}

// MARK: UICollectionViewDataSource conformance
extension PhotoDataSource: UICollectionViewDataSource {
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		
		return photos.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
		return collectionView.dequeueReusableCell(withReuseIdentifier: "UICollectionViewCell", for: indexPath)
	}
}
