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
	
	let photoDataSource = PhotoDataSource()
	let imageStore = ImageStore()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		collectionView.delegate = self
		collectionView.dataSource = photoDataSource
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
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
	
	@IBAction func addCutline() {
		
		let imagePicker = UIImagePickerController()
		
		imagePicker.sourceType = .photoLibrary
		imagePicker.delegate = self
		
		present(imagePicker, animated: true)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		switch segue.identifier! {
			
		case "showCutlineInfo":
			
			if let selectedIndexPath =
				collectionView.indexPathsForSelectedItems?.first {
				
				let photo = photoDataSource.photo(atIndex: selectedIndexPath.row)
				let cutlineInfoController = segue.destination as! CutlineInfoViewController
				
				cutlineInfoController.photo = photo
				cutlineInfoController.photoDataSource = photoDataSource
				cutlineInfoController.imageStore = imageStore
			}
		default:
			preconditionFailure("Unexpected segue identifier")
		}
	}
}

extension CutlinesViewController: UICollectionViewDelegate {

	func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		
		let photo = photoDataSource.photo(atIndex: indexPath.row)
		
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
			
			// TODO: bad
			createViewController.loadView()
			
			createViewController.photoDataSource = self.photoDataSource
			createViewController.imageStore = self.imageStore
			createViewController.imageURL = url
			createViewController.imageView.image = image
			
			self.show(createViewController, sender: self)
		}
	}
}
