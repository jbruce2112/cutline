//
//  EditViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class EditViewController: UIViewController {
	
	// MARK: Properties
	var photo: Photo!
	var photoManager: PhotoManager!
	
	private let containerView = PhotoContainerView()
	
	private var initialCaption: String!
	
	@IBOutlet private var shareButton: UIBarButtonItem!
	@IBOutlet private var deleteButton: UIBarButtonItem!
	@IBOutlet private var toolbar: UIToolbar!
	
	private var canceled = false
	private var deleted = false
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.addSubview(containerView)
		
		photoManager.image(for: photo) { image in
			self.containerView.polaroidView.image = image
		}
		
		// Don't clear the placeholder text
		if !photo.caption!.isEmpty {
			containerView.captionView.text = photo.caption
		}
		
		initialCaption = containerView.captionView.getCaption()
		
		let flipButton = UIBarButtonItem(image: #imageLiteral(resourceName: "refresh"), style: .plain, target: containerView, action: #selector(PhotoContainerView.flip))
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		navigationItem.setRightBarButtonItems([cancelButton, flipButton], animated: false)
		
		// Don't mess with the captionView insets
		automaticallyAdjustsScrollViewInsets = false
	}
	
	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		
		guard let navController = navigationController else {
			return
		}
		
		let toolBarHeight = toolbar.isHidden ? 0 : toolbar.frame.height
		let navBarHeight = navController.navigationBar.isHidden ? 0 : navController.navigationBar.frame.height
		let statusBarHeight = UIApplication.shared.isStatusBarHidden ? 0 : UIApplication.shared.statusBarFrame.height
		
		let barHeights = statusBarHeight + navBarHeight + toolBarHeight
		containerView.heightConstraintConstant = barHeights
		
		containerView.setNeedsLayout()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
		toolbar.setTheme()
		
		// Hide the tabBar from the previous view
		tabBarController?.tabBar.isHidden = true
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		// Update the Photo object with our changes
		// and kick off a save before we leave the view
		let caption = containerView.captionView.getCaption()
		if !deleted && !canceled && caption != initialCaption {
			
			photo.caption = caption
			photo.lastUpdated = NSDate()
			photoManager.update(photo: photo, completion: nil)
		}
		
		// Show the original tab bar again
		tabBarController?.tabBar.isHidden = false
	}
	
	func cancel() {
		
		canceled = true
		let _ = navigationController?.popViewController(animated: true)
	}
	
	// MARK: Actions
	@IBAction func backgroundTapped(_ sender: UITapGestureRecognizer) {
		
		containerView.captionView.endEditing(true)
	}
	
	@IBAction func deleteItem() {
		
		let alertController = UIAlertController(title: nil,
								message: "This caption will be deleted from Cutlines on all your devices.", preferredStyle: .actionSheet)
		
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		let deleteAction = UIAlertAction(title: "Delete Caption", style: .destructive) { _ in
		
			self.deleted = true
			self.photoManager.delete(photo: self.photo, completion: nil)
			let _ = self.navigationController?.popViewController(animated: true)
		}
		
		alertController.addAction(deleteAction)
		alertController.addAction(cancelAction)
		
		// We need to give the alertController an anchor for display when on iPad
		if let presenter = alertController.popoverPresentationController {
			
			guard let deleteButtonView = deleteButton.value(forKey: "view") as? UIView else {
				return
			}
			
			presenter.sourceView = deleteButtonView
			presenter.sourceRect = deleteButtonView.bounds
		}
		
		present(alertController, animated: true, completion: nil)
	}
	
	@IBAction func shareItem() {
		
		let shareController = UIActivityViewController(activityItems:
			[containerView.captionView.getCaption(), containerView.polaroidView.image!], applicationActivities: nil)
		
		if let presenter = shareController.popoverPresentationController {
			
			guard let shareButtonView = shareButton.value(forKey: "view") as? UIView else {
				return
			}
			
			presenter.sourceView = shareButtonView
			presenter.sourceRect = shareButtonView.bounds
		}
		
		present(shareController, animated: true)
	}
}
