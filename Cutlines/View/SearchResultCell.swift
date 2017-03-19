//
//  SearchResultCell.swift
//  Cutlines
//
//  Created by John on 2/19/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class SearchResultCell: UITableViewCell {
	
	// MARK: Properties
	var resultText: String?
	var resultImage: UIImage?
	
	private let resultLabel = UILabel()
	private let resultImageView = UIImageView()
	
	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: .default, reuseIdentifier: "SearchResultCell")
		
		setup()
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		
		setup()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		
		resultLabel.text = resultText
		resultImageView.image = resultImage
		
		resultImageView.clipsToBounds = true
		resultImageView.contentMode = .scaleAspectFill
		resultImageView.translatesAutoresizingMaskIntoConstraints = false
		resultLabel.translatesAutoresizingMaskIntoConstraints = false
		
		var constraints = [NSLayoutConstraint]()
		
		// tie the image to the superviews leadind and top edges
		constraints.append(resultImageView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 5))
		constraints.append(resultImageView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor, constant: 0))
		
		// make the image a square
		constraints.append(resultImageView.widthAnchor.constraint(equalTo: resultImageView.heightAnchor))
		
		// pad the image from the superview's top and bottom edges
		constraints.append(resultImageView.heightAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.heightAnchor, constant: 0))
		
		// set a lower priority for this equality so the image grows as large as it can
		let heightConstraint = resultImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor)
		heightConstraint.priority = UILayoutPriorityDefaultHigh
		constraints.append(heightConstraint)
		
		// Center the label vertically and give it some padding between the image
		constraints.append(resultLabel.centerYAnchor.constraint(equalTo: resultImageView.centerYAnchor))
		constraints.append(resultLabel.leadingAnchor.constraint(equalTo: resultImageView.trailingAnchor, constant: 10))
		
		NSLayoutConstraint.activate(constraints)
		
		separatorInset = UIEdgeInsets(top: 0, left: contentView.frame.height, bottom: 0, right: 0)	}
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		resultLabel.textColor = theme.textColor
	}
	
	// MARK: Private functions
	private func setup() {
		
		accessoryType = .disclosureIndicator
		
		// Using the default textLabel & imageView properties of UITableViewCell
		// results in the cell incorrectly re-laying out its subview when the cell is touched
		// so we just ignore those properties and create our own
		contentView.addSubview(resultLabel)
		contentView.addSubview(resultImageView)
	}
}
