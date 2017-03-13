//
//  PhotoContainerView.swift
//  Cutlines
//
//  Created by John on 3/13/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class PhotoContainerView: UIView {
	
	var captionView = CaptionView()
	var polaroidView = PolaroidView()
	
	var heightConstraintConstant: CGFloat = 0
	
	private var heightConstraint: NSLayoutConstraint?
	private var heightConstraintGTE: NSLayoutConstraint?
	
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
		
		guard let superview = superview else {
			return
		}
		
		var constraints = [NSLayoutConstraint]()
		
		// width = containter.width + 20 @750
		let widthConstraint = superview.widthAnchor.constraint(equalTo: widthAnchor, constant: 20)
		widthConstraint.priority = UILayoutPriorityDefaultHigh
		constraints.append(widthConstraint)
		
		// height >= containter.height + 20
		heightConstraintGTE = superview.heightAnchor.constraint(greaterThanOrEqualTo: heightAnchor, constant: 20)
		constraints.append(heightConstraintGTE!)
		
		// width >= containter.width + 20
		constraints.append(superview.widthAnchor.constraint(greaterThanOrEqualTo: widthAnchor, constant: 20))
		
		// height = containter.height + 20 @750
		heightConstraint = superview.heightAnchor.constraint(equalTo: heightAnchor, constant: 20)
		heightConstraint!.priority = UILayoutPriorityDefaultHigh
		constraints.append(heightConstraint!)
		
		// centerX = containter.centerX
		constraints.append(superview.centerXAnchor.constraint(equalTo: centerXAnchor))
		
		// centerY = containter.centerY
		constraints.append(superview.centerYAnchor.constraint(equalTo: centerYAnchor))
		
		// aspect 1:1
		constraints.append(widthAnchor.constraint(equalTo: heightAnchor))
		
		NSLayoutConstraint.activate(constraints)
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		
		// We can nearly accomplish all the autolayout work in the storyboard,
		// but the container's height constraints need to take the various toolbars into account.
		// The constraints in the storyboard only set the relationship between the view and the container,
		// and the view also extends under the toolbars. This can be disabled, but it looks better if the view
		// extends underneath and then the container just constrains itself within the status bars.
		//let tabBarHeight = tabbar.isHidden ? 0 : .frame.height
		//let navBarHeight = navController.navigationBar.isHidden ? 0 : navController.navigationBar.frame.height
		//let statusBarHeight = UIApplication.shared.isStatusBarHidden ? 0 : UIApplication.shared.statusBarFrame.height
		
		//let barHeights = statusBarHeight + navBarHeight //+ tabBarHeight
		
		// The initial height constraint constant is 20 to allow for some padding
		heightConstraint?.constant = heightConstraintConstant + 20
		heightConstraintGTE?.constant = heightConstraintConstant + 20
		
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
