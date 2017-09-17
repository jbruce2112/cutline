//
//  CollectionViewController.swift
//  Cutlines
//
//  Created by John on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class CollectionViewController: UIViewController {
	
	// MARK: Properties
	var photoManager: PhotoManager!
	fileprivate var photoStore: PhotoStore!
	
	@IBOutlet fileprivate var collectionView: UICollectionView!
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		photoStore = photoManager.photoStore
		
		collectionView.delegate = self
		collectionView.dataSource = self
		
		photoManager.delegate = self
		
		registerForPreviewing(with: self, sourceView: collectionView)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
		refresh()
	}
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		collectionView.backgroundColor = theme.backgroundColor
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		switch segue.identifier! {
		
		case "showEdit":
			guard
				let cell = sender as? UICollectionViewCell,
				let selectedIndex = self.collectionView.indexPath(for: cell) else {
					return
			}
			
			let photo = self.photoStore.photos[selectedIndex.row]
			let editViewController = segue.destination as! EditViewController
			
			editViewController.photo = photo
			editViewController.photoManager = self.photoManager
		case "showSettings":
			break
		default:
			preconditionFailure("Unexpected segue identifier")
		}
	}
	
	func refresh() {
		
		photoStore.refresh { result in
			
			switch result {
				
			case .success:
				self.collectionView.reloadData()
			case let .failure(error):
				log("Error refreshing data source \(error)")
			}
		}
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
		// invalidate the current layout so we can reset the cell sizes for the new screen aspect
		collectionView.collectionViewLayout.invalidateLayout()
	}
	
	// MARK: Actions
	@IBAction func add() {
		
		let imagePicker = UIImagePickerController()
		
		imagePicker.sourceType = .photoLibrary
		imagePicker.delegate = self
		
		present(imagePicker, animated: true)
	}
}

// MARK: UICollectionViewDelegateFlowLayout conformance
extension CollectionViewController: UICollectionViewDelegateFlowLayout {
	
	func collectionView(_ collectionView: UICollectionView,
	                    layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		
		let cellSpacing = Double((collectionViewLayout as! UICollectionViewFlowLayout).minimumInteritemSpacing)
		
		let viewWidth = Double(collectionView.bounds.width)
		
		// Calculate the cell size at runtime so we can make
		// the cells as large as possible on all resolutions
		// (i.e. no excessive padding)
		// This results in the following layouts:
		// iPhone 7 & 7 Plus Portrait - 4 cells, Landscape - 6 cells
		// iPad 9.7 Portrait - 7 cells, Landscape - 8
		// iPad 12.9 Portrait - 8 cells , Landscape - 10 cells
		let maxPtsPerCell: Double = 153
		let cellsPerRow = ceil(viewWidth / maxPtsPerCell) + 1
		
		// Account for padding
		let cellWidth = floor(viewWidth / cellsPerRow) - cellSpacing
		return CGSize(width: cellWidth, height: cellWidth)
	}
}

// MARK: UICollectionViewDelegate conformance
extension CollectionViewController: UICollectionViewDelegate {

	func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		
		let photo = photoStore.photos[indexPath.row]
		
		// First, check for a cached thumbnail so we can
		// avoid the delay of resetting it asynchronously
		// (this can cause the collectionView to flash during reload)
		let imageView = cell.viewWithTag(100) as! UIImageView
		imageView.image = photoManager.cachedThumbnail(for: photo, withSize: cell.frame.size)
		
		if imageView.image != nil {
			return
		}
		
		// No cached thumbnail yet - create one and set it async
		photoManager.thumbnail(for: photo, withSize: cell.frame.size) { fetchedThumbnail in
			
			guard let thumbnail = fetchedThumbnail else {
				return
			}
			
			// Ask the collectionView for the cell at this
			// index again to make sure it's still available
			guard let cell = self.collectionView.cellForItem(at: indexPath) else {
				return
			}
			
			let imageView = cell.viewWithTag(100) as! UIImageView
			imageView.image = thumbnail
		}
	}
}

// MARK: ImagePickerControllerDelegate conformance
extension CollectionViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
		
		// get picked image from the info dictionary
		guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
			return
		}
		
		var fileURL: URL? = nil
		var assetURL: URL? = nil
		
		// UIImagePickerControllerReferenceURL is deprecated as of iOS 11
		// the system will also skip the photo library authorization prompt to the user
		// if we avoid using the ALAsset API and instead use the new ImageURL key
		if #available(iOS 11.0, *) {
			fileURL = info[UIImagePickerControllerImageURL] as? URL
		} else {
			assetURL = info[UIImagePickerControllerReferenceURL] as? URL
		}
		
		// dismiss the image picker
		picker.dismiss(animated: true) {
		
			let createViewController =
				self.storyboard!.instantiateViewController(withIdentifier: "CreateViewController") as! CreateViewController
			
			createViewController.photoManager = self.photoManager
			createViewController.assetURL = assetURL
			createViewController.fileURL = fileURL
			createViewController.image = image
			
			self.navigationController?.pushViewController(createViewController, animated: true)
		}
	}
	
	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true)
	}
}

// MARK: PhotoChangeDelegate conformance
extension CollectionViewController: PhotoChangeDelegate {
	
	func didAdd() {
		refresh()
	}
	
	func didRemove() {
		refresh()
	}
}

// MARK: UICollectionViewDataSource conformance
extension CollectionViewController: UICollectionViewDataSource {
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		
		return photoStore.photos.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
		return collectionView.dequeueReusableCell(withReuseIdentifier: "UICollectionViewCell", for: indexPath)
	}
}


// MARK: - 3D Touch Support
extension CollectionViewController: UIViewControllerPreviewingDelegate {
	
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
		
		let editController = viewControllerToCommit as! EditViewController
		editController.toolbar.isHidden = false
		
		navigationController?.pushViewController(editController, animated: true)
	}
	
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
		
		guard let selectedIndexPath = collectionView.indexPathForItem(at: location) else {
			return nil
		}
		
		if let cell = collectionView.cellForItem(at: selectedIndexPath) {
			previewingContext.sourceRect = cell.frame
		}
		
		let editController =
			self.storyboard!.instantiateViewController(withIdentifier: "EditViewController") as! EditViewController
		
		let photo = photoStore.photos[selectedIndexPath.row]
		editController.photo = photo
		editController.photoManager = photoManager
		editController.previewer = self
		
		// Make sure the toolbar is set
		editController.loadViewIfNeeded()
		
		editController.toolbar.isHidden = true
		
		return editController
	}
}
