//
//  SearchResultCell.swift
//  Cutline
//
//  Created by John on 2/19/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class SearchResultCell: UITableViewCell {
	
	// MARK: Properties
	var result: SearchResult!
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
		constraints.append(resultLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10))
		
		NSLayoutConstraint.activate(constraints)
		
		resultLabel.text = getLabelText()
	}
	
	private func getLabelText() -> String {
		
		let captionNoNewline = result.photo.caption!.replacingOccurrences(of: "\n", with: " ")
		let captionLowercased = captionNoNewline.lowercased()
		
		let matchStartIndex = captionLowercased.range(of: result.searchTerm)!.lowerBound
		
		var displayStart = captionLowercased.startIndex
		
		let displayString = captionNoNewline.substring(from: displayStart)
		
		// See if we would end up truncating the string if it was displayed
		let labelWidth = resultLabel.frame.size.width
		let displaySize = displayString.size(attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 17.0)])
		
		if displaySize.width < labelWidth || labelWidth == 0 {
			return displayString
		}
		
		// The string will be truncated when displayed.
		// Determine if the searchTerm's position in the string
		// is far enough in that we need to truncate the leading
		// characters in order for the term itself to be viewable.
		
		let leadingPaddingChars = 10
		
		if captionLowercased.distance(from: captionLowercased.startIndex, to: matchStartIndex) > leadingPaddingChars {
			
			// We need to truncate the beginning
			displayStart = captionLowercased.index(matchStartIndex, offsetBy: -1 * leadingPaddingChars)
			return "...\(captionNoNewline.substring(from: displayStart))"
		} else {
			
			// The searchTerm is near the beginning, and the label
			// will truncate the trailing characters for us
			return displayString
		}
		
	}
	
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
