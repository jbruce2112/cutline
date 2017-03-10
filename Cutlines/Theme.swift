//
//  Theme.swift
//  Cutlines
//
//  Created by John on 2/19/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

@objc
class Theme: NSObject {
	
	var backgroundColor: UIColor!
	var altBackgroundColor: UIColor!
	var textColor: UIColor!
	var accentColor: UIColor!
	var barStyle: UIBarStyle!
	var isNight = false
}

extension UIViewController {
	
	@objc
	func setTheme() {
		setTheme(view.theme())
	}
	
	@objc
	func setTheme(_ theme: Theme) {
		view.setTheme(theme)
	}
}

extension UIView {
	
	@objc
	func setTheme() {
		setTheme(theme())
	}
	
	@objc
	func setTheme(_ theme: Theme) {
		backgroundColor = theme.backgroundColor
	}
	
	func theme() -> Theme {
		
		let theme = Theme()
		
		if appGroupDefaults.bool(forKey: Key.nightMode.rawValue) {
			
			theme.isNight = true
			theme.backgroundColor = .black
			theme.altBackgroundColor = UIColor(colorLiteralRed: 25.0 / 255.0, green: 25.0 / 225.0, blue: 25.0 / 225.0, alpha: 1.0)
			theme.textColor = tintColor
			theme.accentColor = .white
			theme.barStyle = .black
		} else {
			
			theme.isNight = false
			theme.backgroundColor = .white
			theme.altBackgroundColor = UIColor(colorLiteralRed: 227.0 / 255.0, green: 227.0 / 255.0, blue: 227.0 / 255.0, alpha: 1.0)
			theme.textColor = .black
			theme.accentColor = .blue
			theme.barStyle = .default
		}
		
		return theme
	}
}

extension UITabBar {
	
	override func setTheme(_ theme: Theme) {
		barStyle = theme.barStyle
	}
}

extension UINavigationBar {
	
	override func setTheme(_ theme: Theme) {
		barStyle = theme.barStyle
	}
}

extension UIToolbar {
	
	override func setTheme(_ theme: Theme) {
		barStyle = theme.barStyle
	}
}

extension UITableViewCell {
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		textLabel?.textColor = theme.textColor
		
		let selectedView = UIView()
		selectedView.backgroundColor = theme.altBackgroundColor
		
		selectedBackgroundView = selectedView
	}
}
