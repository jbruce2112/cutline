//
//  CreateViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/31/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class CreateViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
	
	@IBOutlet var imageView: UIImageView!
	@IBOutlet var captionView: UITextView!
	
	private var displayedImagePicker = false
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		//TODO: jank fest?
		if !displayedImagePicker {
			
			let imagePicker = UIImagePickerController()
			
			imagePicker.sourceType = .photoLibrary
			imagePicker.delegate = self
			
			present(imagePicker, animated: true)
			
			displayedImagePicker = true
		}
	}
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		
		// get picked image from the info dictionary
		imageView.image = info[UIImagePickerControllerOriginalImage] as? UIImage
		
		// dismiss the image picker
		dismiss(animated: true, completion: nil)
	}
}
