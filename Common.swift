//
//  Common.swift
//  Cutlines
//
//  Created by John on 2/12/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import Foundation

let appGroupDomain = "group.com.jbruce32.Cutlines"
let cloudContainerDomain = "iCloud.com.jbruce32.Cutlines"

let appGroupDefaults: UserDefaults = {
	
	let defaults = UserDefaults(suiteName: appGroupDomain)!
	
	// Register default preference values here since we only have a couple preferences
	let defaultValues: [String: Any] = [Key.cellSync.rawValue: true,
	                                    Key.darkMode.rawValue: true]
	
	defaults.register(defaults: defaultValues)
	
	return defaults
}()

let appGroupURL = {
	
	return FileManager.default.containerURL(
		forSecurityApplicationGroupIdentifier: appGroupDomain)!
}()

let captionPlaceholder = "Enter your caption"
