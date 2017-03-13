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
	
	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		
		guard let navController = navigationController, let tabController = tabBarController else {
			return
		}
		
		let tabBarHeight = tabController.tabBar.isHidden ? 0 : tabController.tabBar.frame.height
		let navBarHeight = navController.navigationBar.isHidden ? 0 : navController.navigationBar.frame.height
		let statusBarHeight = UIApplication.shared.isStatusBarHidden ? 0 : UIApplication.shared.statusBarFrame.height
		
		let barHeights = statusBarHeight + navBarHeight + tabBarHeight
		containerView.heightConstraintConstant = barHeights
		
		containerView.setNeedsLayout()
	}
	
	func cancel() {
		
		canceled = true
		let _ = navigationController?.popViewController(animated: true)
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
				
				Log("Error fetching asset URL \(imageURL.absoluteString)")
				return
			}
		
		photoManager.add(image: image, caption: containerView.captionView.getCaption(), dateTaken: asset.creationDate!, qos: nil, completion: nil)
	}
}
