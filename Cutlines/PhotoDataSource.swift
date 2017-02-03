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
	case success
	case failure(Error)
}

class PhotoDataSource: NSObject {
	
	fileprivate var photos = [Photo]()
	
	private let persistantContainer: NSPersistentContainer = {
		
		let container = NSPersistentContainer(name: "Cutlines")
		container.loadPersistentStores { (description, error) in
			if let error = error {
				print("Error setting up Core Data \(error)")
			}
		}
		return container
	}()
	
	func photo(atIndex index: Int) -> Photo {
		
		return photos[index]
	}
	
	func refresh(completion: @escaping (UpdateResult) -> Void) {
		
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		
		let sortByDateAdded = NSSortDescriptor(key: #keyPath(Photo.dateAdded), ascending: true)
		fetchRequest.sortDescriptors = [sortByDateAdded]
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			do {
				try self.photos = viewContext.fetch(fetchRequest)
				completion(.success)
			} catch {
				completion(.failure(error))
			}
		}
	}
	
	func addPhoto(id: String, caption: String, dateTaken: Date, completion: @escaping (UpdateResult) -> Void) {
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			let entityDescription = NSEntityDescription.entity(forEntityName: "Photo", in: viewContext)
			let photo = NSManagedObject.init(entity: entityDescription!, insertInto: viewContext) as! Photo
			photo.photoID = id
			photo.caption = caption
			photo.dateTaken = dateTaken as NSDate
			photo.dateAdded = NSDate()
			photo.lastUpdated = NSDate()
			
			viewContext.insert(photo)
			
			do {
				try viewContext.save()
				completion(.success)
			}
			catch {
				completion(.failure(error))
			}
		}
	}
}

extension PhotoDataSource: UICollectionViewDataSource {
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		
		return photos.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
		return collectionView.dequeueReusableCell(withReuseIdentifier: "UICollectionViewCell", for: indexPath)
	}
}
