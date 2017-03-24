//
//  CreateViewController.swift
//  Cutline
//
//  Created by John Bruce on 1/31/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit
import Photos

class CreateViewController: UIViewController {

	// MARK: Properties
	var image: UIImage!
	var imageURL: URL!
	var photoManager: PhotoManager!
	
	private var containerView = PhotoContainerView()
	private var canceled = false
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.addSubview(containerView)
		
		containerView.polaroidView.image = image
		
		let flipButton = UIBarButtonItem(image: #imageLiteral(resourceName: "refresh"), style: .plain, target: containerView, action: #selector(PhotoContainerView.flip))
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		
		navigationItem.setRightBarButtonItems([cancelButton, flipButton], animated: false)
		
		navigationItem.title = "Create"
		
		// Don't mess with the captionView insets
		automaticallyAdjustsScrollViewInsets = false
		
		// Grow the containerView as large as the top and bottom layout guides permit
		
		// containter.top = topLayoutGuide.bottom + 10
		let topEQ = containerView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: 10)
		
		// bottomLayoutGuide.top = container.bottom + 10
		let bottomEQ = bottomLayoutGuide.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 10)
		
		topEQ.priority = UILayoutPriorityDefaultHigh
		bottomEQ.priority = UILayoutPriorityDefaultHigh
		
		topEQ.isActive = true
		bottomEQ.isActive = true
		
		// container.top >= topLayoutGuide.bottom + 10
		containerView.topAnchor.constraint(greaterThanOrEqualTo: topLayoutGuide.bottomAnchor, constant: 10).isActive = true
		
		// bottomLayoutGuide.top >= container.bottom + 10
		bottomLayoutGuide.topAnchor.constraint(greaterThanOrEqualTo: containerView.bottomAnchor, constant: 10).isActive = true
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		if !canceled {
			save()
		}
	}
	
	func cancel() {
		
		canceled = true
		_ = navigationController?.popViewController(animated: true)
	}
	
	// MARK: Actions
	@IBAction func backgroundTapped(_ sender: UITapGestureRecognizer) {
		
		containerView.captionView.endEditing(true)
	}
	
	private func save() {
		
		let results = PHAsset.fetchAssets(withALAssetURLs: [imageURL], options: nil)
		
		defer {
			navigationController!.popViewController(animated: true)
		}
		
		guard
			let asset = results.firstObject else  {
				
				log("Error fetching asset URL \(imageURL.absoluteString)")
				return
			}
		
		photoManager.add(image: image, caption: containerView.captionView.getCaption(), dateTaken: asset.creationDate!, qos: nil, completion: nil)
	}
}
