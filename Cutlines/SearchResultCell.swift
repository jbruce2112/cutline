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
		
		// TODO: Make this cell's imageView look more
		// consistent across landscape/portrait images
		let size = contentView.frame.size
		imageView?.widthAnchor.constraint(equalToConstant: size.width * 0.2)
		imageView?.heightAnchor.constraint(equalToConstant: size.height)
		
		imageView?.contentMode = .scaleAspectFill
	}
}
