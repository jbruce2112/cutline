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
	
	var imageView = UIImageView()
	var textView = UITextView()
	
	@IBOutlet var container: UIView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		imageView.frame = CGRect(x: 0, y:0, width: container.frame.width,
		                         height: container.frame.height)
		textView.frame = imageView.frame
		
		container.addSubview(imageView)
		
		imageView.image = imageStore.image(forKey: photo.photoID!)
		textView.text = photo.caption
		
		container.layer.borderWidth = 1.5
		container.layer.borderColor = UIColor.gray.cgColor
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		flipPhoto()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		// Update the Photo object with our changes
		// and kick off a save before we leave the view
		photo.caption = textView.text
		photoDataSource.save()
	}
	
	func flipPhoto() {
		
		// Set up the views as a tuple in case we want to
		// flip this view again later on
		var views: (frontView: UIView, backView: UIView)
		
		if imageView.superview != nil {
			views = (frontView: imageView, backView: textView)
		} else {
			views = (frontView: textView, backView: imageView)
		}
		
		UIView.transition(from: views.frontView, to: views.backView,
		                  duration: 0.5, options: [.transitionFlipFromRight, .curveEaseOut], completion: nil)
	}
}
