//
//  ImageStore.swift
//  Cutlines
//
//  Created by John Bruce on 1/22/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import ImageIO
import UIKit

class ImageStore {
	
	// MARK: Properties
	private let cache = NSCache<NSString, UIImage>()
	
	private let imageDirURL: URL = {
		
		return appGroupURL.appendingPathComponent("images")
	}()
	
	init() {
		
		try! FileManager.default.createDirectory(at: imageDirURL,
		                                         withIntermediateDirectories: true, attributes: nil)
	}
	
	// MARK: Functions
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
	
	func thumbnail(forKey key: String, size: CGSize) -> UIImage? {
		
		let url = imageURL(forKey: key)
		
		guard let original = CGImageSourceCreateWithURL(url as CFURL, nil) else {
			return nil
		}
		
		// Get the aspect ratio of the original image
		let propOptions: [NSString: Any] = [kCGImageSourceShouldCache: false]
		guard let origProps = CGImageSourceCopyPropertiesAtIndex(original, 0, propOptions as CFDictionary?) else {
			return nil
		}
		
		let origDictionary = origProps as Dictionary
		let originalWidth = origDictionary[kCGImagePropertyPixelWidth] as! Double
		let originalHeight = origDictionary[kCGImagePropertyPixelHeight] as! Double
		
		let aspectRatio = CGFloat(max(originalWidth, originalHeight) / min(originalHeight, originalWidth))
		
		// Convert from points to pixels.
		// Also, since we are unable to specify a 'minimum size' for
		// the thumbnail, we also multiply by the aspect ratio so the
		// shortest side of the thumbnail is as large as the shortest side of the original image
		let maxPixelSize = max(size.width, size.height) * aspectRatio * UIScreen.main.scale
		
		let options: [NSString: Any] = [
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
			kCGImageSourceCreateThumbnailFromImageAlways: true
		]
		
		// The Image I/O framework will cache the thumbnail for us
		return CGImageSourceCreateThumbnailAtIndex(original, 0, options as CFDictionary?).flatMap { UIImage(cgImage: $0) }
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
	
	func imageURL(forKey key: String) -> URL {
		return imageDirURL.appendingPathComponent(key)
	}
}
