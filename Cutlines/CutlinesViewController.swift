//
//  CutlinesViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class CutlinesViewController: UIViewController, UICollectionViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
	
	@IBOutlet var collectionView: UICollectionView!
	
	let photoDataSource = PhotoDataSource()
	let imageStore = ImageStore()
	
	var newImage: UIImage?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		collectionView.delegate = self
		collectionView.dataSource = photoDataSource
		
		photoDataSource.update {
			(result) in
			
			if result == .success {
				self.collectionView.reloadData()
			}
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		
		let photo = photoDataSource.photo(atIndex: indexPath.row)
		
		if let image = imageStore.image(forKey: photo.photoID!),
			let cell = collectionView.cellForItem(at: indexPath) {
			
			let imageView = cell.viewWithTag(0) as! UIImageView
			imageView.image = image
		}
	}
	
	@IBAction func addPhoto(_ sender: UIBarButtonItem) {
		
		let imagePicker = UIImagePickerController()
		
		imagePicker.sourceType = .photoLibrary
		imagePicker.delegate = self
		
		present(imagePicker, animated: true)
	}
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		
		// get picked image from the info dictionary
		newImage = info[UIImagePickerControllerOriginalImage] as? UIImage
		
		// dismiss the image picker
		dismiss(animated: true)  {
		
			let createViewController =
				self.storyboard?.instantiateViewController(withIdentifier: "CreateViewController") as! CreateViewController
			
			createViewController.image = self.newImage
			
			self.present(createViewController, animated: true)
		}
	}
}
