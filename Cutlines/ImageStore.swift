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
	private let thumbCache = NSCache<NSString, UIImage>()
	
	private let imageDirURL: URL = {
		
		return appGroupURL.appendingPathComponent("images")
	}()
	
	private let thumbDirURL: URL = {
		
		return FileManager.default.urls(for: .cachesDirectory,
		                                in: .userDomainMask).first!.appendingPathComponent("thumbnails")
	}()
	
	init() {
		
		try! FileManager.default.createDirectory(at: imageDirURL,
		                                         withIntermediateDirectories: true, attributes: nil)
		
		try! FileManager.default.createDirectory(at: thumbDirURL,
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
		
		// Check the thumbnail cache first
		let thumbKey = key + "_\(max(size.width, size.height))"
		if let exisitingThumbnail = thumbCache.object(forKey: thumbKey as NSString) {
			return exisitingThumbnail
		}
		
		// Check the disk for an archived thumbnail
		let thumbnailURL = thumbURL(forKey: thumbKey)
		if let thumbFromDisk = UIImage(contentsOfFile: thumbnailURL.path) {
			
			// Got a thumbnail from disk, add it to the cache and return
			thumbCache.setObject(thumbFromDisk, forKey: thumbKey as NSString)
			return thumbFromDisk
		}
		
		// Don't have a thumbnail for this image and size yet - create one
		guard let thumbnail = createThumbnail(forKey: key, size: size) else {
			return nil
		}
		
		// Write the thumbnail to disk and add it to our cache
		thumbCache.setObject(thumbnail, forKey: thumbKey as NSString)
		
		if let data = UIImageJPEGRepresentation(thumbnail, 0.7) {
			let _ = try? data.write(to: thumbnailURL, options: [.atomic])
		}
		
		return thumbnail
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
	
	// MARK: Private functions
	private func thumbURL(forKey key: String) -> URL {
		return thumbDirURL.appendingPathComponent(key)
	}
	
	private func createThumbnail(forKey key: String, size: CGSize) -> UIImage? {
		
		let originalImageURL = imageURL(forKey: key)
		guard let original = CGImageSourceCreateWithURL(originalImageURL as CFURL, nil) else {
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
			kCGImageSourceCreateThumbnailFromImageAlways: true]
		
		// Convert from CGOrientation to UIImageOrientation
		// so the returned image is correctly oriented
		let cgOrientation = origDictionary[kCGImagePropertyOrientation] as? Int
		let orientation = uiOrientation(fromCGOrientation: cgOrientation)
		
		return CGImageSourceCreateThumbnailAtIndex(original, 0, options as CFDictionary?).flatMap {
			UIImage(cgImage: $0, scale: 1.0, orientation: orientation)
		}
	}
	
	private func uiOrientation(fromCGOrientation cgOrientation: Int?) -> UIImageOrientation {
		
		guard let cgOrientation = cgOrientation else {
			return .up
		}
		
		switch cgOrientation {
		case 1:
			return .up
		case 2:
			return .upMirrored
		case 3:
			return .down
		case 4:
			return .downMirrored
		case 5:
			return .leftMirrored
		case 6:
			return .right
		case 7:
			return .rightMirrored
		case 8:
			return .left
		default:
			return .up
		}
	}
}
