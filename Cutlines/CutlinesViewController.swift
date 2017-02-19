//
//  CutlinesViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class CutlinesViewController: UIViewController {
	
	@IBOutlet var collectionView: UICollectionView!
	
	var photoDataSource: PhotoDataSource!
	var imageStore: ImageStore!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		collectionView.delegate = self
		collectionView.dataSource = photoDataSource
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		refresh()
	}
	
	@IBAction func addCutline() {
		
		let imagePicker = UIImagePickerController()
		
		imagePicker.sourceType = .photoLibrary
		imagePicker.delegate = self
		
		present(imagePicker, animated: true)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		let showCutlineInfo = { (animated: Bool) -> Void in
			
			if let cell = sender as? UICollectionViewCell,
			   let selectedIndexPath =
				self.collectionView.indexPath(for: cell) {
				
				let photo = self.photoDataSource.photos[selectedIndexPath.row]
				let cutlineInfoController = segue.destination as! CutlineInfoViewController
				
				cutlineInfoController.photo = photo
				cutlineInfoController.photoDataSource = self.photoDataSource
				cutlineInfoController.imageStore = self.imageStore
				cutlineInfoController.animatedFlip = animated
			}
		}
		
		switch segue.identifier! {
			
		case "showCutlineInfo":
			showCutlineInfo(true)
		case "showCutlineInfoNoFlip":
			showCutlineInfo(false)
		case "showSettings":
			break
		default:
			preconditionFailure("Unexpected segue identifier")
		}
	}
	
	func refresh() {
		
		photoDataSource.refresh {
			(result) in
			
			switch result {
				
			case .success:
				self.collectionView.reloadData()
			case let .failure(error):
				print("Error refreshing data source \(error)")
			}
		}
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
		// invalidate the current layout so we can reset the cell sizes for the new screen aspect
		collectionView.collectionViewLayout.invalidateLayout()
	}
}

extension CutlinesViewController: UICollectionViewDelegateFlowLayout {
	
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		
		let cellSpacing = Double((collectionViewLayout as! UICollectionViewFlowLayout).minimumInteritemSpacing)
		
		let viewWidth = Double(collectionView.bounds.width)
		
		// Around 150 pts per cell. This grows with resolution pretty well.
		// iPhone 7 & 7 Plus Portrait - 4 cells, Landscape - 6 cells
		// iPad 9.7 Portrait - 7 cells, Landscape - 8
		// iPad 12.9 Portrait - 8 cells , Landscape - 10 cells, etc.
		let cellsPerRow = ceil(viewWidth / 153) + 1
		
		// Round the computed width down to the nearest 10th
		let cellWidth = (floor(viewWidth / cellsPerRow) / 10) * 10 - cellSpacing
		return CGSize(width: cellWidth, height: cellWidth)
	}
}

extension CutlinesViewController: UICollectionViewDelegate {

	func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		
		let photo = photoDataSource.photos[indexPath.row]
		
		if let image = imageStore.image(forKey: photo.photoID!) {
			
			let imageView = cell.viewWithTag(100) as! UIImageView
			imageView.image = image
		}
	}
}

extension CutlinesViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		
		// get picked image from the info dictionary
		let image = info[UIImagePickerControllerOriginalImage] as? UIImage
		let url = info[UIImagePickerControllerReferenceURL] as? URL
		
		// dismiss the image picker
		dismiss(animated: true) {
		
			let createViewController =
				self.storyboard!.instantiateViewController(withIdentifier: "CreateViewController") as! CreateViewController
			
			createViewController.loadViewIfNeeded()
			
			createViewController.photoDataSource = self.photoDataSource
			createViewController.imageStore = self.imageStore
			createViewController.imageURL = url
			createViewController.imageView.image = image
			
			self.show(createViewController, sender: self)
		}
	}
}
