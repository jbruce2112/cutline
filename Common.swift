//
//  Common.swift
//  Cutlines
//
//  Created by John on 2/12/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import Foundation

let AppGroupURL = {
	
	return FileManager.default.containerURL(
		forSecurityApplicationGroupIdentifier: "group.com.bruce32.Cutlines")?.appendingPathComponent("SharedPhotos")
}()

let SharedPhotoImageSuffix = "image"
let SharedPhotoCaptionSuffix = "caption"
