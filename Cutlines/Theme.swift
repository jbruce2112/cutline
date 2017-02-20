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
		
		let appDelegate = UIApplication.shared.delegate as! AppDelegate
		if appDelegate.defaults.bool(forKey: Key.darkMode.rawValue) {
			
			theme.backgroundColor = .black
			theme.textColor = UIColor(colorLiteralRed: 0, green: 122.0 / 255, blue: 255, alpha: 1)
			theme.accentColor = .white
		} else {
			
			theme.backgroundColor = .white
			theme.textColor = .black
			theme.accentColor = .blue
		}
		
		return theme
	}
}
