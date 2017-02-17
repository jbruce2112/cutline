//
//  CreateViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/31/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit
import Photos

class CreateViewController: UIViewController {
	
	@IBOutlet var imageView: UIImageView!
	@IBOutlet var captionView: CaptionView!
	
	var photoDataSource: PhotoDataSource!
	var imageStore: ImageStore!
	var imageURL: URL!
	
	fileprivate let placeholderText = "Your notes here"
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		navigationItem.rightBarButtonItem =
			UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(save))
		
		navigationItem.title = "Create"
		
		// TODO: Make this view grow/shrink depending on if the keyboard is present
		captionView.layer.borderWidth = 1
		captionView.layer.borderColor = UIColor.black.cgColor
	}
	
	@IBAction func save() {
		
		// TODO: use non-deprecated api
		let results = PHAsset.fetchAssets(withALAssetURLs: [imageURL!], options: nil)
		
		guard
			let image = imageView.image,
			let asset = results.firstObject else  {
				print("Error fetching asset URL \(imageURL.absoluteString)")
				navigationController!.popViewController(animated: true)
				return
			}
		
			let id = NSUUID().uuidString
			imageStore.setImage(image, forKey: id)
			
			photoDataSource.addPhoto(id: id, caption: captionView.text, dateTaken: asset.creationDate!) {
				(result) in
				
				switch result {
				case .success:
					// TODO: bad
					var _ = 0
				case let .failure(error):
					print("Cutline save failed with error: \(error)")
				}
			}
		
		navigationController!.popViewController(animated: true)
	}
}
