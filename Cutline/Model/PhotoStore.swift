//
//  PhotoStore.swift
//  Cutline
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

class PhotoStore: NSObject {
	
	// MARK: Properties
	private var _photos = [Photo]()
	var photos: [Photo] {
		get {
			dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
			return _photos
		}
		set {
			dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
			_photos = newValue
		}
	}
	
	private let entityName = "Photo"
	
	private let persistantContainer: NSPersistentContainer
	
	init(storeURL: URL? = nil) {
		
		let persistantStoreURL = storeURL ?? appGroupURL.appendingPathComponent("PhotoStore.sqlite")
		
		persistantContainer = NSPersistentContainer(name: "Cutline")
		persistantContainer.persistentStoreDescriptions = [NSPersistentStoreDescription(url: persistantStoreURL)]
		persistantContainer.loadPersistentStores { (_, error) in
			
			if let error = error {
				log("Error setting up Core Data \(error)")
			}
		}
	}
	
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
		
		let predicate = NSPredicate(format: "\(#keyPath(Photo.ckRecord)) == nil AND \(#keyPath(Photo.markedDeleted)) == NO")
		return fetch(withPredicate: predicate, limit: limit)
	}
	
	func fetchModified(limit: Int?) -> [Photo] {
		
		let predicate = NSPredicate(format: "\(#keyPath(Photo.dirty)) == YES AND \(#keyPath(Photo.markedDeleted)) == NO")
		return fetch(withPredicate: predicate, limit: limit)
	}
	
	func fetchDeleted(limit: Int?) -> [Photo] {
		
		let predicate = NSPredicate(format: "\(#keyPath(Photo.markedDeleted)) == YES")
		return fetch(withPredicate: predicate, limit: limit)
	}
	
	func fetch(withID id: String) -> Photo? {
		
		let predicate = NSPredicate(format: "\(#keyPath(Photo.id)) == %@ AND \(#keyPath(Photo.markedDeleted)) == NO", id)
		return fetch(withPredicate: predicate, limit: 1).first
	}
	
	func fetch(containing searchTerm: String) -> [Photo] {
		
		let predicate = NSPredicate(format: "\(#keyPath(Photo.caption)) contains[c] %@ AND \(#keyPath(Photo.markedDeleted)) == NO", searchTerm)
		return fetch(withPredicate: predicate, limit: nil)
	}
	
	func add(_ photo: CloudPhoto, completion: @escaping (UpdateResult) -> Void) {
		
		add(id: photo.id, caption: photo.caption, dateTaken: photo.dateTaken as Date) { result in
		
			switch result {
				
			case let .success(newPhoto):
				
				let viewContext = self.persistantContainer.viewContext
				
				// Set the remaining properties
				newPhoto!.ckRecord = photo.ckRecord
				newPhoto!.dateAdded = photo.dateAdded
				newPhoto!.lastUpdated = photo.lastUpdated
				
				do {
					
					try viewContext.save()
					completion(.success(newPhoto))
				} catch {
					
					completion(.failure(error))
				}
				
			case let .failure(error):
				completion(.failure(error))
			}
		}
	}
	
	func add(id: String, caption: String, dateTaken: Date, completion: @escaping (UpdateResult) -> Void) {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			assert(caption != captionPlaceholder)
			
			let entityDescription = NSEntityDescription.entity(forEntityName: self.entityName, in: viewContext)
			let photo = NSManagedObject(entity: entityDescription!, insertInto: viewContext) as! Photo
			photo.id = id
			photo.caption = caption
			photo.dateTaken = dateTaken as NSDate
			photo.dateAdded = NSDate()
			photo.lastUpdated = NSDate()
			
			viewContext.insert(photo)
			
			do {
				try viewContext.save()
				completion(.success(photo))
			} catch {
				log("Error saving context \(error)")
				viewContext.rollback()
				completion(.failure(error))
			}
		}
	}
	
	func delete(withID id: String, completion: @escaping (UpdateResult) -> Void) {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			let fetchPred = NSPredicate(format: "\(#keyPath(Photo.id)) == %@", id)
			
			guard let photo = self.fetch(withPredicate: fetchPred, limit: 1).first else {
				log("Photo not deleted from CoreData because we couldn't find it")
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
	
	func save() {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			do {
				try viewContext.save()
			} catch {
				viewContext.rollback()
				log("Error saving context \(error)")
			}
		}
	}
	
	private func fetch(withPredicate predicate: NSPredicate, limit: Int?) -> [Photo] {
		
		var photos = [Photo]()
		
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		fetchRequest.predicate = predicate
		
		if let limit = limit {
			fetchRequest.fetchLimit = limit
		}
		
		let viewContext = persistantContainer.viewContext
		viewContext.performAndWait {
			
			do {
				try photos = viewContext.fetch(fetchRequest)
			} catch {
				log("Error fetching photos \(error)")
			}
		}
		
		return photos
	}
}
