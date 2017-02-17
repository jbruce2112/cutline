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
	
	var animatedFlip = false
	
	let imageView = UIImageView()
	let captionView = CaptionView()
	
	@IBOutlet var container: UIView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if animatedFlip {
			container.addSubview(imageView)
		} else {
			container.addSubview(captionView)
		}
		
		imageView.image = imageStore.image(forKey: photo.photoID!)
		imageView.contentMode = .scaleAspectFit
		
		captionView.text = photo.caption
		
		container.layer.borderWidth = 2.0
		container.layer.borderColor = UIColor.gray.cgColor
		
		container.layer.shadowRadius = 5
		container.layer.shadowColor = UIColor.gray.cgColor
		container.layer.shadowOpacity = 0.6
		
		navigationItem.rightBarButtonItem =
			UIBarButtonItem(image: #imageLiteral(resourceName: "refresh"), style: .plain, target: self, action: #selector(flipPhoto))
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		// Set container's subview frames to its bounds here
		// to give autolayout a chance to finish sizing the container
		imageView.frame = container.bounds
		captionView.frame = container.bounds
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		if animatedFlip {
			flipPhoto()
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		// Update the Photo object with our changes
		// and kick off a save before we leave the view		
		if captionView.text != captionView.placeholderText {
			photo.caption = captionView.text
			photo.lastUpdated = NSDate()
			photoDataSource.save()
		}
	}
	
	func flipPhoto() {
		
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
