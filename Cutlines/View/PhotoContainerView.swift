//
//  PhotoContainerView.swift
//  Cutlines
//
//  Created by John on 3/13/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

/// PhotoContainerView combines a
/// CaptionView and PolaroidView subviews
/// on opposite sides of a single container view.
class PhotoContainerView: UIView {
	
	var captionView = CaptionView()
	var polaroidView = PolaroidView()
	
	private var constraintsSet = false
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		
		setup()
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		
		setup()
	}
	
	override func updateConstraints() {
		super.updateConstraints()
		
		// We only need to set these once
		if constraintsSet {
			return
		}
		
		guard let superview = superview else {
			return
		}
		
		var constraints = [NSLayoutConstraint]()
		
		// width = self.width + 20 @750
		let widthConstraint = superview.widthAnchor.constraint(equalTo: widthAnchor, constant: 20)
		widthConstraint.priority = UILayoutPriorityDefaultHigh
		constraints.append(widthConstraint)
		
		// superview.width >= self.width + 20
		constraints.append(superview.widthAnchor.constraint(greaterThanOrEqualTo: widthAnchor, constant: 20))
		
		// superview.centerX = self.centerXAnchor
		constraints.append(superview.centerXAnchor.constraint(equalTo: centerXAnchor))
		
		// superview.centerY = self.centerYAnchor
		constraints.append(superview.centerYAnchor.constraint(equalTo: centerYAnchor))
		
		// aspect 1:1
		constraints.append(widthAnchor.constraint(equalTo: heightAnchor))
		
		NSLayoutConstraint.activate(constraints)
		
		constraintsSet = true
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		
		polaroidView.frame = bounds
		captionView.frame = bounds
	}
	
	func flip() {
		
		// Set up the views as a tuple in case we want to
		// flip this view again later on
		var subViews: (frontView: UIView, backView: UIView)
		
		if polaroidView.superview != nil {
			subViews = (frontView: polaroidView, backView: captionView)
		} else {
			subViews = (frontView: captionView, backView: polaroidView)
		}
		
		UIView.transition(from: subViews.frontView, to: subViews.backView,
		                  duration: 0.4, options: [.transitionFlipFromRight, .curveEaseOut], completion: nil)
	}
	
	private func setup() {
		
		addSubview(captionView)
		
		backgroundColor = UIColor(colorLiteralRed: 255.0 / 255.0, green: 254.0 / 255.0, blue: 245.0 / 255.0, alpha: 1.0)
		
		polaroidView.setNeedsLayout()
		
		layer.borderWidth = 0.75
		layer.borderColor = UIColor.gray.cgColor
		
		layer.shadowRadius = 10
		layer.shadowColor = UIColor.gray.cgColor
		layer.shadowOpacity = 0.6
		
		translatesAutoresizingMaskIntoConstraints = false
	}
}
