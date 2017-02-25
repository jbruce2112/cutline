//
//  CutlineInfoViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class CutlineInfoViewController: UIViewController {
	
	var photo: Photo!
	var photoDataSource: PhotoDataSource!
	var imageStore: ImageStore!
	
	var animated = false
	
	private let imageView = UIImageView()
	private let captionView = CaptionView()
	
	@IBOutlet private var container: UIView!
	
	private var initialCaption: String!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if animated {
			container.addSubview(imageView)
		} else {
			container.addSubview(captionView)
		}
		
		imageView.image = imageStore.image(forKey: photo.photoID!)
		imageView.contentMode = .scaleAspectFit
		
		captionView.text = photo.caption
		initialCaption = captionView.getCaption()
		
		container.layer.borderWidth = 2.0
		container.layer.borderColor = UIColor.gray.cgColor
		
		container.layer.shadowRadius = 5
		container.layer.shadowColor = UIColor.gray.cgColor
		container.layer.shadowOpacity = 0.6
		
		navigationItem.rightBarButtonItem =
			UIBarButtonItem(image: #imageLiteral(resourceName: "refresh"), style: .plain, target: self, action: #selector(flipContainer))
	}
	
	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		
		guard
			let tabController = tabBarController,
			let navController = navigationController else {
				return
		}
		
		// We can nearly accomplish all the autolayout work in the storyboard,
		// but the container's height constraints need to take the various toolbars into account.
		// The constraints in the storyboard only set the relationship between the view and the container,
		// and the view also extends under the toolbars. This can be disabled, but it looks better if the view
		// extends underneath and then the container just constrains itself within the status bars.
		let tabBarHeight = tabController.tabBar.isHidden ? 0 : tabController.tabBar.frame.height
		let navBarHeight = navController.navigationBar.isHidden ? 0 : navController.navigationBar.frame.height
		let statusBarHeight = UIApplication.shared.isStatusBarHidden ? 0 : UIApplication.shared.statusBarFrame.height
		
		let barHeights = statusBarHeight + navBarHeight + tabBarHeight
		
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
		imageView.frame = container.bounds
		captionView.frame = container.bounds
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		if self.animated {
			flipContainer()
		}
		
		// TODO: Temporary place to force a CloudKit upload action
		let cloudManager = (UIApplication.shared.delegate as! AppDelegate).cloudManager
		cloudManager.save(photo: photo) { (result) in
			
			switch result {
			case .success:
				break
			case let .failure(error):
				print("Got error from cloudkit add: \(error)")
			}
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		// Update the Photo object with our changes
		// and kick off a save before we leave the view
		let caption = captionView.getCaption()
		if caption != initialCaption {
			
			photo.caption = caption
			photo.lastUpdated = NSDate()
			photoDataSource.save()
		}
	}
	
	func flipContainer() {
		
		// Set up the views as a tuple in case we want to
		// flip this view again later on
		var views: (frontView: UIView, backView: UIView)
		
		if imageView.superview != nil {
			views = (frontView: imageView, backView: captionView)
		} else {
			views = (frontView: captionView, backView: imageView)
		}
		
		UIView.transition(from: views.frontView, to: views.backView,
		                  duration: 0.5, options: [.transitionFlipFromRight, .curveEaseOut], completion: nil)
	}
}
