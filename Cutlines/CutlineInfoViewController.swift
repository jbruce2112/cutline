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
	
	@IBOutlet var imageView: UIImageView!
	@IBOutlet var textView: UITextView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		imageView.image = imageStore.image(forKey: photo.photoID!)
		textView.text = photo.caption
	}
}
