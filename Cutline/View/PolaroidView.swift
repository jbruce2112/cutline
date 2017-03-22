//
//  PolaroidView.swift
//  Cutline
//
//  Created by John on 3/6/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import Foundation
import UIKit

class PolaroidView: UIView {
	
	var image: UIImage?
	private var imageView = UIImageView()
	
	override func layoutSubviews() {
		super.layoutSubviews()
		
		imageView.image = image
		
		addSubview(imageView)
		
		imageView.clipsToBounds = true		
		imageView.contentMode = .scaleAspectFill
		
		imageView.translatesAutoresizingMaskIntoConstraints = false
		
		var constraints = [NSLayoutConstraint]()
		constraints.append(imageView.topAnchor.constraint(equalTo: self.topAnchor, constant: 15))
		constraints.append(imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 15))
		constraints.append(imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -15))
		constraints.append(imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -60))
		
		NSLayoutConstraint.activate(constraints)
	}
}
