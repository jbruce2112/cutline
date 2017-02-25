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
	
	func fetchOnlyLocal(limit: Int) -> [Photo] {
		
		var localPhotos = [Photo]()
		
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "\(#keyPath(Photo.inCloud)) == NO")
		fetchRequest.fetchLimit = limit
		
		let viewContext = persistantContainer.viewContext
		viewContext.performAndWait {
			
			do {
				try localPhotos = viewContext.fetch(fetchRequest)
			} catch {
				print("Error fetching local photos \(error)")
			}
		}
		
		return localPhotos
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
	
	// Non-blocking
	func addPhoto(id: String, caption: String, dateTaken: Date, completion: @escaping (UpdateResult) -> Void) {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			// Call the blocking version
			let result = self.addPhoto(id: id, caption: caption, dateTaken: dateTaken)
			completion(result)
		}
	}
	
	// Blocking
	func addPhoto(id: String, caption: String, dateTaken: Date) -> UpdateResult {
		
		let viewContext = persistantContainer.viewContext
		var result: UpdateResult!
		viewContext.performAndWait {
			
			assert(caption != captionPlaceholder)
			
			let entityDescription = NSEntityDescription.entity(forEntityName: self.entityName, in: viewContext)
			let photo = NSManagedObject(entity: entityDescription!, insertInto: viewContext) as! Photo
			photo.photoID = id
			photo.caption = caption
			photo.dateTaken = dateTaken as NSDate
			photo.dateAdded = NSDate()
			photo.lastUpdated = NSDate()
			photo.inCloud = false
			
			viewContext.insert(photo)
			
			do {
				try viewContext.save()
				result = .success(photo)
			} catch {
				viewContext.rollback()
				result = .failure(error)
			}
		}
		
		return result
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
