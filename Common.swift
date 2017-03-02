//
//  Common.swift
//  Cutlines
//
//  Created by John on 2/12/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import Foundation

let appGroupDomain = "group.com.jbruce32.Cutlines"

let appGroupDefaults = UserDefaults(suiteName: appGroupDomain)!

let appGroupURL = {
	
	return FileManager.default.containerURL(
		forSecurityApplicationGroupIdentifier: appGroupDomain)!
}()

let sharedPhotoImageSuffix = "image"
let sharedPhotoCaptionSuffix = "caption"

let captionPlaceholder = "Enter your caption"
