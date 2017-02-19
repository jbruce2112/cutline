//
//  SettingsViewController.swift
//  Cutlines
//
//  Created by John on 2/17/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {
	
	@IBOutlet var versionLabel: UILabel!
	@IBOutlet var attributionTextView: UITextView!
	
	@IBOutlet var syncLabel: UILabel!
	@IBOutlet var darkModeLabel: UILabel!
	
	let version: String = {
		
		guard
			let infoDict = Bundle.main.infoDictionary,
			let build = infoDict[kCFBundleVersionKey as String] as? String,
			let version = infoDict["CFBundleShortVersionString"] as? String else {
				return "0.0.0"
		}
		
		return "Version \(version).\(build)"
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		versionLabel.text = version
		
		let linkTitle = "Icons8"
		let text = "Icon pack by \(linkTitle)" as NSString
		let linkTitleRange = text.range(of: linkTitle)
		
		// Create an AttributedString with the Icons8 URL with the standard system font
		let attribution = NSMutableAttributedString(string: text as String)
		attribution.addAttribute(NSLinkAttributeName, value: "https://icons8.com", range: linkTitleRange)
		attribution.addAttribute(NSFontAttributeName, value: UIFont.systemFont(ofSize: 17.0), range: NSMakeRange(0, text.length))
		attributionTextView.attributedText = attribution
		
		// Align the leading edge with the versionLabel
		attributionTextView.textContainer.lineFragmentPadding = 0
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		versionLabel.textColor = theme.textColor
		attributionTextView.textColor = theme.textColor
		
		syncLabel.textColor = theme.textColor
		darkModeLabel.textColor = theme.textColor
		
		for cell in tableView.visibleCells {
			cell.backgroundColor = theme.backgroundColor
		}
//		
//		for i in 0...tableView.numberOfSections {
//			let section = tableView.headerView(forSection: i)
//			section?.backgroundColor = theme.backgroundColor
//			section?.textLabel?.textColor = theme.textColor
//			
//			let footer = tableView.footerView(forSection: i)
//			footer?.backgroundColor = theme.backgroundColor
//			footer?.textLabel?.textColor = theme.textColor
//		}
	}
	
	@IBAction func toggleDarkMode(sender: UISwitch) {
		
		(UIApplication.shared.delegate as! AppDelegate).toggleDarkMode(sender.isOn)
		setTheme()
	}
}
