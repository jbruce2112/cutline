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
	
	var imageView = UIImageView()
	var captionView = CaptionView()
	
	@IBOutlet var container: UIView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		imageView.frame = CGRect(x: 0, y:0, width: container.frame.width,
		                         height: container.frame.height)
		captionView.frame = imageView.frame
		
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
		//container.layer.shadowOffset = CGSize(width: 0, height: 2)
		
		navigationItem.rightBarButtonItem =
			UIBarButtonItem(title: "Flip", style: .plain, target: self, action: #selector(flipPhoto))
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
		photo.caption = captionView.text
		photoDataSource.save()
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
