//
//  Common.swift
//  Cutlines
//
//  Created by John on 2/12/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import Foundation

let appGroupURL = {
	
	return FileManager.default.containerURL(
		forSecurityApplicationGroupIdentifier: "group.com.jbruce32.Cutlines")!.appendingPathComponent("SharedPhotos")
}()

let sharedPhotoImageSuffix = "image"
let sharedPhotoCaptionSuffix = "caption"

let captionPlaceholder = "Enter your caption"
