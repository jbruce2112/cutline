//
//  SettingsViewController.swift
//  Cutlines
//
//  Created by John on 2/17/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {
	
	@IBOutlet var versionLabel: UILabel!
	@IBOutlet var attributionLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		guard let version = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String else {
			return
		}
		
		versionLabel.text = "Version \(version)"
		attributionLabel.text = "Icons pack by Icons8: https://icons8.com"
	}
	
}
