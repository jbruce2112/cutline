//
//  SearchResultCell.swift
//  Cutlines
//
//  Created by John on 2/19/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class SearchResultCell: UITableViewCell {
	
	override func layoutSubviews() {
		super.layoutSubviews()
		
		guard let imageView = imageView, let textLabel = textLabel else {
			return
		}
		
		imageView.clipsToBounds = true
		imageView.contentMode = .scaleAspectFill
		imageView.translatesAutoresizingMaskIntoConstraints = false
		textLabel.translatesAutoresizingMaskIntoConstraints = false
		
		var constraints = [NSLayoutConstraint]()
		
		// tie the image to the superviews leadind and top edges
		constraints.append(imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5))
		constraints.append(imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5))
		
		// make the image a square
		constraints.append(imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor))
		
		// pad the image from the superview's top and bottom edges
		constraints.append(imageView.heightAnchor.constraint(lessThanOrEqualTo: contentView.heightAnchor, constant: -10))
		
		// set a lower priority for this equality so the image grows as large as it can
		let heightConstraint = imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor)
		heightConstraint.priority = UILayoutPriorityDefaultHigh
		constraints.append(heightConstraint)
		
		// Center the label vertically and give it some padding between the image
		constraints.append(textLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor))
		constraints.append(textLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10))
		
		NSLayoutConstraint.activate(constraints)
		
		separatorInset = UIEdgeInsets(top: 0, left: contentView.frame.size.height, bottom: 0, right: 0)
	}
}
