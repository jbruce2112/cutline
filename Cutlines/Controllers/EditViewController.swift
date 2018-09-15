//
//  EditViewController.swift
//  Cutlines
//
//  Created by John on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class EditViewController: UIViewController {
	
	// MARK: Properties
	var photo: Photo!
	var photoManager: PhotoManager!
	
	private let containerView = PhotoContainerView()
	
	private var initialCaption: String!
	
	weak var previewer: UIViewController?
	@IBOutlet var toolbar: UIToolbar!
	
	@IBOutlet private var shareButton: UIBarButtonItem!
	@IBOutlet private var deleteButton: UIBarButtonItem!
	
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
		
		navigationItem.title = "Edit"
		
		navigationItem.rightBarButtonItem =
			UIBarButtonItem(image: #imageLiteral(resourceName: "refresh"), style: .plain, target: containerView, action: #selector(PhotoContainerView.flip))
		
		// Grow the containerView as large as the topLayoutGuide and toolbar permits
		
		// containter.top = topLayoutGuide.bottom + 10
		let topEQ = containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
		
		// toolbar.top = container.bottom + 10
		let bottomEQ = toolbar.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 10)
		
		topEQ.priority = UILayoutPriority.defaultHigh
		bottomEQ.priority = UILayoutPriority.defaultHigh
		
		topEQ.isActive = true
		bottomEQ.isActive = true
		
		// container.top >= topLayoutGuide.bottom + 10
		containerView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
		
		// toolbar.top >= container.bottom + 10
		toolbar.topAnchor.constraint(greaterThanOrEqualTo: containerView.bottomAnchor, constant: 10).isActive = true
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
		if !deleted && caption != initialCaption {
			
			photo.caption = caption
			photo.lastUpdated = Date()
			photoManager.update(photo: photo, completion: nil)
		}
		
		// Show the original tab bar again
		tabBarController?.tabBar.isHidden = false
	}
	
	// MARK: Actions
	@IBAction func backgroundTapped(_ sender: UITapGestureRecognizer) {
		
		containerView.captionView.endEditing(true)
	}
	
	@IBAction func deleteItem(_ sender: UIBarButtonItem) {
		deleteItem(nil)
	}
	
	@IBAction func shareItem(_ sender: UIBarButtonItem) {
		shareItem(nil)
	}
	
	// MARK: Private functions
	private func deleteItem(_ previewController: UIViewController?) {
		
		let alertController = UIAlertController(title: nil,
								message: "This caption will be deleted from Cutlines on all your devices.", preferredStyle: .actionSheet)
		
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		let deleteAction = UIAlertAction(title: "Delete Caption", style: .destructive) { _ in
		
			self.deleted = true
			self.photoManager.delete(photo: self.photo, completion: nil)
			_ = self.navigationController?.popViewController(animated: true)
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
		
		let presentingController = previewController ?? self
		presentingController.present(alertController, animated: true, completion: nil)
	}
	
	private func shareItem(_ previewController: UIViewController?) {
		
		let shareController = UIActivityViewController(activityItems:
			[containerView.captionView.getCaption(), containerView.polaroidView.image!], applicationActivities: nil)
		
		if let presenter = shareController.popoverPresentationController {
			
			guard let shareButtonView = shareButton.value(forKey: "view") as? UIView else {
				return
			}
			
			presenter.sourceView = shareButtonView
			presenter.sourceRect = shareButtonView.bounds
		}
		
		let presentingController = previewController ?? self
		presentingController.present(shareController, animated: true)
	}
}

// MARK: UIPreviewActionItems for 3D touch
extension EditViewController {
	
	override var previewActionItems: [UIPreviewActionItem] {
		
		let shareAction = UIPreviewAction(title: "Share", style: .default) { [weak self] _, _ in
			
			guard let strongSelf = self else {
				return
			}
			
			strongSelf.shareItem(strongSelf.previewer)
		}
		
		let deleteAction = UIPreviewAction(title: "Delete", style: .destructive) { [weak self] _, _ in
			
			guard let strongSelf = self else {
				return
			}
			
			strongSelf.deleteItem(strongSelf.previewer)
		}
		
		return [shareAction, deleteAction]
	}
}

// MARK: UIGestureRecognizerDelegate
extension EditViewController: UIGestureRecognizerDelegate {
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		
		// Ignore touch events on the toolbar
		if let touchView = touch.view, touchView.isDescendant(of: toolbar) {
			return false
		} else {
			return true
		}
	}
}
