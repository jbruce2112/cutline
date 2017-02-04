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
	@IBOutlet var captionView: UITextView!
	
	var photoDataSource: PhotoDataSource!
	var imageStore: ImageStore!
	var imageURL: URL!
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		navigationItem.rightBarButtonItem =
			UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(save))
		
		navigationItem.title = "Create Caption"
	}
	
	@IBAction func save() {
		
		let results = PHAsset.fetchAssets(withALAssetURLs: [imageURL!], options: nil)
		
		if results.count == 1, let asset = results.firstObject {
			
			let id = NSUUID().uuidString
			imageStore.setImage(imageView.image!, forKey: id)
			
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
		} else {
			print("Error fetching asset URL \(imageURL.absoluteString)")
		}
		
		navigationController!.popViewController(animated: true)
	}
}
