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
	case failure
}

class PhotoDataSource: NSObject, UICollectionViewDataSource {
	
	private var photos = [Photo]()
	
	private let persistantContainer: NSPersistentContainer = {
		
		let container = NSPersistentContainer(name: "Cutlines")
		container.loadPersistentStores { (description, error) in
			if let error = error {
				print("Error setting up Core Data \(error)")
			}
		}
		return container
	}()
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		
		return photos.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
		return collectionView.dequeueReusableCell(withReuseIdentifier: "UICollectionViewCell", for: indexPath)
	}
	
	func photo(atIndex index: Int) -> Photo {
		
		return photos[index]
	}
	
	func update(completion: @escaping (UpdateResult) -> Void) {
		
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		
		let sortByDateAdded = NSSortDescriptor(key: #keyPath(Photo.dateAdded), ascending: true)
		fetchRequest.sortDescriptors = [sortByDateAdded]
		
		let viewContext = persistantContainer.viewContext
		viewContext.perform {
			
			do {
				try self.photos = viewContext.fetch(fetchRequest)
				completion(.success)
			} catch {
				completion(.failure)
			}
		}
	}
}
