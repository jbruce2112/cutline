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
	
	@IBOutlet var cellSyncLabel: UILabel!
	@IBOutlet var darkModeLabel: UILabel!
	
	@IBOutlet var cellSyncSwitch: UISwitch!
	@IBOutlet var darkModeSwitch: UISwitch!
	
	let defaults: UserDefaults = {
		
		let appDelegate = UIApplication.shared.delegate as! AppDelegate
		return appDelegate.defaults
	}()
	
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
		
		// load preferences
		cellSyncSwitch.isOn = defaults.bool(forKey: Key.cellSync.rawValue)
		darkModeSwitch.isOn = defaults.bool(forKey: Key.darkMode.rawValue)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		versionLabel.textColor = theme.textColor
		attributionTextView.textColor = theme.textColor
		attributionTextView.backgroundColor = theme.backgroundColor
		
		cellSyncLabel.textColor = theme.textColor
		darkModeLabel.textColor = theme.textColor
		
		for cell in tableView.visibleCells {
			cell.backgroundColor = theme.backgroundColor
		}
		
		// force the section headers to refresh
		tableView.reloadSections(IndexSet(integer: 0), with: .none)
		tableView.reloadSections(IndexSet(integer: 1), with: .none)
	}
	
	// MARK: UI Actions
	@IBAction private func toggleCellSync(sender: UISwitch) {
		
		defaults.set(sender.isOn, forKey: Key.cellSync.rawValue)
	}
	
	@IBAction private func toggleDarkMode(sender: UISwitch) {
		
		// Set the theme for the whole app
		let appDelegate = UIApplication.shared.delegate as! AppDelegate
		appDelegate.setDarkMode(sender.isOn)
		
		// Force our view to refresh since it's in the foreground
		setTheme()
	}
	
	private func setDarkMode(_ enabled: Bool) {
		
	}
}
