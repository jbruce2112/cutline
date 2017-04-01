//
//  SettingsViewController.swift
//  Cutlines
//
//  Created by John on 2/17/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {
	
	@IBOutlet private var versionLabel: UILabel!
	
	@IBOutlet private var iconsLabel: UILabel!
	@IBOutlet private var iconsButton: UIButton!
	
	@IBOutlet private var privacyLabel: UILabel!
	
	@IBOutlet private var cellSyncLabel: UILabel!
	@IBOutlet private var darkModeLabel: UILabel!
	
	@IBOutlet private var cellSyncSwitch: UISwitch!
	@IBOutlet private var darkModeSwitch: UISwitch!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		versionLabel.text = getVersion()
		
		let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(iconsLabelTapped))
		iconsLabel.addGestureRecognizer(gestureRecognizer)
		
		iconsButton.addTarget(self, action: #selector(openIconsURL), for: .touchUpInside)
		
		// load preferences
		cellSyncSwitch.isOn = appGroupDefaults.bool(forKey: PrefKey.cellSync)
		darkModeSwitch.isOn = appGroupDefaults.bool(forKey: PrefKey.nightMode)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		var backgroundColor: UIColor!
		var foregroundColor: UIColor!
		
		// Styling this view controller is a special case for now
		if theme.isNight {
			backgroundColor = theme.backgroundColor
			foregroundColor = theme.altBackgroundColor
		} else {
			backgroundColor = theme.altBackgroundColor
			foregroundColor = theme.backgroundColor
		}
		
		view.backgroundColor = backgroundColor
		
		versionLabel.textColor = theme.textColor
		iconsLabel.textColor = theme.textColor
		iconsLabel.backgroundColor = foregroundColor
		privacyLabel.textColor = theme.textColor
		
		cellSyncLabel.textColor = theme.textColor
		darkModeLabel.textColor = theme.textColor
		
		for cell in tableView.visibleCells {
			cell.backgroundColor = foregroundColor
		}
		
		// force the section headers to refresh
		tableView.reloadSections(IndexSet(integer: 0), with: .none)
		tableView.reloadSections(IndexSet(integer: 1), with: .none)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		switch segue.identifier! {
		case "showPrivacy":
			
			let vc = segue.destination as! WebViewController
			vc.url = Bundle.main.url(forResource: "privacy", withExtension: "html")			
		default:
			break
		}
	}
	
	func openIconsURL() {
		
		// Open the icons URL in the browser
		UIApplication.shared.open(URL(string: "https://icons8.com")!, options: [:], completionHandler: nil)
	}
	
	func iconsLabelTapped(recognizer: UITapGestureRecognizer) {
		
		if recognizer.state == UIGestureRecognizerState.ended {
			
			openIconsURL()
		}
	}
	
	private func getBuildDate() -> Date {
		
		guard
			let infoPath = Bundle.main.path(forResource: "Info.plist", ofType: nil),
			let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
			let infoDate = infoAttr[.modificationDate] as? Date else {
				
				return Date()
		}
		
		return infoDate
	}
	
	private func getBuildVersion() -> String {
		
		guard
			let infoDict = Bundle.main.infoDictionary,
			let version = infoDict["CFBundleShortVersionString"] as? String else {
				return "0.0"
		}
		
		return version
	}
	
	private func getVersion() -> String {
		
		let version = "Version \(getBuildVersion())"
		
		#if DEBUG
			
			let formatter = DateFormatter()
			formatter.locale = Locale(identifier: "en_US")
			formatter.dateStyle = .medium
			formatter.timeStyle = .medium
			
			let buildDate = formatter.string(from: getBuildDate())
			return "\(version) built on \(buildDate)"
		#else
			return version
		#endif
	}
	
	// MARK: UI Actions
	@IBAction private func toggleCellSync(sender: UISwitch) {
		
		appGroupDefaults.set(sender.isOn, forKey: PrefKey.cellSync)
	}
	
	@IBAction private func toggleDarkMode(sender: UISwitch) {
		
		appGroupDefaults.set(sender.isOn, forKey: PrefKey.nightMode)
		
		// Set the theme in the delegate for the root controllers
		let appDelegate = UIApplication.shared.delegate as! AppDelegate
		appDelegate.setTheme()
		
		// Force our view to refresh since it's in the foreground
		setTheme()
	}
}
