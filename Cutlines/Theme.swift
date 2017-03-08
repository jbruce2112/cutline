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
	var textColor: UIColor!
	var accentColor: UIColor!
	var barStyle: UIBarStyle!
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
		
		if appGroupDefaults.bool(forKey: Key.darkMode.rawValue) {
			
			theme.backgroundColor = .black
			theme.textColor = tintColor
			theme.accentColor = .white
			theme.barStyle = .black
		} else {
			
			theme.backgroundColor = .white
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

extension UITableViewCell {
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		backgroundColor = theme.backgroundColor
		textLabel?.textColor = theme.textColor
	}
}
