//
//  ImageStore.swift
//  Cutlines
//
//  Created by John Bruce on 1/22/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class ImageStore {
	
	private let cache = NSCache<NSString, UIImage>()
	
	private let imageDirURL: URL = {
		
		var docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		return docsDir.appendingPathComponent("images")
	}()
	
	init() {
		
		try! FileManager.default.createDirectory(at: imageDirURL, withIntermediateDirectories: true, attributes: nil)
	}
	
	func setImage(_ image: UIImage, forKey key: String) {
		
		cache.setObject(image, forKey: key as NSString)
		
		let url = imageURL(forKey: key)
		
		if let data = UIImageJPEGRepresentation(image, 1) {
			let _ = try? data.write(to: url, options: [.atomic])
		}
	}
	
	func image(forKey key: String) -> UIImage? {
		
		if let exisitingImage = cache.object(forKey: key as NSString) {
			return exisitingImage
		}
		
		let url = imageURL(forKey: key)
		guard let imageFromDisk = UIImage(contentsOfFile: url.path) else {
			return nil
		}
		
		cache.setObject(imageFromDisk, forKey: key as NSString)
		return imageFromDisk
	}
	
	func deleteImage(forKey key: String) {
		cache.removeObject(forKey: key as NSString)
		
		let url = imageURL(forKey: key)
		
		do {
			try FileManager.default.removeItem(at: url)
		} catch {
			print("Error removing the image from disk: \(error)")
		}
	}
	
	private func imageURL(forKey key: String) -> URL {
		return imageDirURL.appendingPathComponent(key)
	}
}
