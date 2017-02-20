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

	var imageURL: URL!
	var imageStore: ImageStore!
	var photoDataSource: PhotoDataSource!

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		navigationItem.rightBarButtonItem =
			UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(save))
		
		navigationItem.title = "Create"
		
		captionView.layer.borderWidth = 1
		captionView.layer.borderColor = UIColor.black.cgColor
		
		// Let the captionView fill 80% of the available height of its parent
		let topConstraint = view.constraints.first { $0.identifier == "captionViewTopConstraint" }
		topConstraint!.constant = view.bounds.height * 0.1
		let bottomConstraint = view.constraints.first { $0.identifier == "captionViewBottomConstraint" }
		bottomConstraint!.constant = view.bounds.height * 0.1
		
		// And fill 80% of its parent's width
		let leadingConstraint = view.constraints.first { $0.identifier == "captionViewLeadingConstraint" }
		leadingConstraint!.constant = view.bounds.width * 0.1
		let trailingConstraint = view.constraints.first { $0.identifier == "captionViewTrailingConstraint" }
		trailingConstraint!.constant = view.bounds.width * 0.1
		
		setTheme()
	}
	
	@IBAction func save() {
		
		let results = PHAsset.fetchAssets(withALAssetURLs: [imageURL!], options: nil)
		
		defer {
			navigationController!.popViewController(animated: true)
		}
		
		guard
			let image = imageView.image,
			let asset = results.firstObject else  {
				
				print("Error fetching asset URL \(imageURL.absoluteString)")
				return
			}
		
			let id = NSUUID().uuidString
			imageStore.setImage(image, forKey: id)
		
			photoDataSource.addPhoto(id: id, caption: captionView.getCaption(), dateTaken: asset.creationDate!) { (result) in
				
				switch result {
				case .success:
					break
				case let .failure(error):
					print("Cutline save failed with error: \(error)")
				}
			}
	}
}
