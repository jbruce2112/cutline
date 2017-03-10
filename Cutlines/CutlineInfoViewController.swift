//
//  CutlineInfoViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class CutlineInfoViewController: UIViewController {
	
	// MARK: Properties
	var photo: Photo!
	var photoManager: PhotoManager!
	
	private let polaroidView = PolaroidView()
	private let captionView = CaptionView()
	
	private var initialCaption: String!
	
	@IBOutlet private var container: UIView!
	@IBOutlet private var shareButton: UIBarButtonItem!
	@IBOutlet private var deleteButton: UIBarButtonItem!
	@IBOutlet private var toolbar: UIToolbar!
	
	private var didDelete = false
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		container.addSubview(captionView)
		
		captionView.backgroundColor = UIColor(colorLiteralRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
		
		polaroidView.image = photoManager.image(for: photo)
		polaroidView.setNeedsLayout()
		
		// Don't clear the placeholder text
		if !photo.caption!.isEmpty {
			captionView.text = photo.caption
		}
		
		initialCaption = captionView.getCaption()
		
		container.layer.borderWidth = 0.75
		container.layer.borderColor = UIColor.gray.cgColor
		
		container.layer.shadowRadius = 10
		container.layer.shadowColor = UIColor.gray.cgColor
		container.layer.shadowOpacity = 0.6
		
		navigationItem.rightBarButtonItem =
			UIBarButtonItem(image: #imageLiteral(resourceName: "refresh"), style: .plain, target: self, action: #selector(flipContainer))
		
		// Don't mess with the captionView insets
		automaticallyAdjustsScrollViewInsets = false
	}
	
	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		
		guard
			let navController = navigationController else {
				return
		}
		
		// We can nearly accomplish all the autolayout work in the storyboard,
		// but the container's height constraints need to take the various toolbars into account.
		// The constraints in the storyboard only set the relationship between the view and the container,
		// and the view also extends under the toolbars. This can be disabled, but it looks better if the view
		// extends underneath and then the container just constrains itself within the status bars.
		let toolBarHeight = toolbar.isHidden ? 0 : toolbar.frame.height
		let navBarHeight = navController.navigationBar.isHidden ? 0 : navController.navigationBar.frame.height
		let statusBarHeight = UIApplication.shared.isStatusBarHidden ? 0 : UIApplication.shared.statusBarFrame.height
		
		let barHeights = statusBarHeight + navBarHeight + toolBarHeight
		
		let heightConstraintLTE = view.constraints.first { $0.identifier == "containerHeightConstraintLTE" }
		let heightConstraint = view.constraints.first { $0.identifier == "containerHeightConstraint" }
		
		// The initial height constraint constant is 20 to allow for some padding
		heightConstraint?.constant = barHeights + 20
		heightConstraintLTE?.constant = barHeights + 20
		
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		// Set container's subview frames to its bounds here
		// to give autolayout a chance to finish sizing the container
		polaroidView.frame = container.bounds
		captionView.frame = container.bounds
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
		let caption = captionView.getCaption()
		if !didDelete && caption != initialCaption {
			
			photo.caption = caption
			photo.lastUpdated = NSDate()
			photoManager.update(photo: photo, completion: nil)
		}
		
		// Show the original tab bar again
		tabBarController?.tabBar.isHidden = false
	}
	
	func flipContainer() {
		
		// Set up the views as a tuple in case we want to
		// flip this view again later on
		var views: (frontView: UIView, backView: UIView)
		
		if polaroidView.superview != nil {
			views = (frontView: polaroidView, backView: captionView)
		} else {
			views = (frontView: captionView, backView: polaroidView)
		}
		
		UIView.transition(from: views.frontView, to: views.backView,
		                  duration: 0.4, options: [.transitionFlipFromRight, .curveEaseOut], completion: nil)
	}
	
	@IBAction func backgroundTapped(_ sender: UITapGestureRecognizer) {
		
		captionView.endEditing(true)
	}
	
	@IBAction func deleteItem() {
		
		let alertController = UIAlertController(title: nil,
								message: "This caption will be deleted from Cutlines on all your devices.", preferredStyle: .actionSheet)
		
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		let deleteAction = UIAlertAction(title: "Delete Caption", style: .destructive) { _ in
		
			self.didDelete = true
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
			[captionView.getCaption(), polaroidView.image!], applicationActivities: nil)
		
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
