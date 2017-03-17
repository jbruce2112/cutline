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
	
	private let imageDirURL: URL
	private let thumbDirURL: URL
	
	private let imageQuality: CGFloat = 0.9
	private let thumbQuality: CGFloat = 0.6
	
	init(imageDirURL: URL? = nil, thumbDirURL: URL? = nil) {
		
		self.imageDirURL = imageDirURL ?? appGroupURL.appendingPathComponent("images")
		self.thumbDirURL = thumbDirURL ?? FileManager.default.urls(for: .cachesDirectory,
			                                in: .userDomainMask).first!.appendingPathComponent("thumbnails")
		
		try! FileManager.default.createDirectory(at: self.imageDirURL,
		                                         withIntermediateDirectories: true, attributes: nil)
		
		try! FileManager.default.createDirectory(at: self.thumbDirURL,
		                                         withIntermediateDirectories: true, attributes: nil)
	}
	
	// MARK: Functions
	func setImage(_ image: UIImage, forKey key: String) {
		
		cache.setObject(image, forKey: key as NSString)
		
		let url = imageURL(forKey: key)
		
		if let data = UIImageJPEGRepresentation(image, imageQuality) {
			let _ = try? data.write(to: url, options: [.atomic])
		}
	}
	
	func image(forKey key: String, completion: @escaping (UIImage?) -> Void) {
		
		if let exisitingImage = cache.object(forKey: key as NSString) {
			completion(exisitingImage)
			return
		}
		
		DispatchQueue.global().async {
			
			let url = self.imageURL(forKey: key)
			guard let imageFromDisk = UIImage(contentsOfFile: url.path) else {
				completion(nil)
				return
			}
			
			self.cache.setObject(imageFromDisk, forKey: key as NSString)
			completion(imageFromDisk)
		}
	}
	
	func thumbnail(forKey key: String, size: CGSize, completion: @escaping (UIImage?) -> Void) {
		
		// Check the thumbnail cache first
		let thumbKey = key + "_\(max(size.width, size.height))"
		if let exisitingThumbnail = thumbCache.object(forKey: thumbKey as NSString) {
			completion(exisitingThumbnail)
			return
		}
		
		DispatchQueue.global().async {
			
			// Check the disk for an archived thumbnail
			let thumbnailURL = self.thumbURL(forKey: thumbKey)
			if let thumbFromDisk = UIImage(contentsOfFile: thumbnailURL.path) {
				
				// Got a thumbnail from disk, add it to the cache and return
				self.thumbCache.setObject(thumbFromDisk, forKey: thumbKey as NSString)
				completion(thumbFromDisk)
				return
			}
			
			// Don't have a thumbnail for this image and size yet - create one
			guard let thumbnail = self.createThumbnail(forKey: key, size: size) else {
				completion(nil)
				return
			}
			
			// Write the thumbnail to disk and add it to our cache
			self.thumbCache.setObject(thumbnail, forKey: thumbKey as NSString)
			
			if let data = UIImageJPEGRepresentation(thumbnail, self.thumbQuality) {
				let _ = try? data.write(to: thumbnailURL, options: [.atomic])
			}
			
			completion(thumbnail)
		}
	}
	
	func deleteImage(forKey key: String, completion: @escaping () -> Void) {
		
		DispatchQueue.global().async {
			
			self.cache.removeObject(forKey: key as NSString)
			
			let url = self.imageURL(forKey: key)
			
			do {
				try FileManager.default.removeItem(at: url)
			} catch {
				Log("Error removing the image from disk: \(error)")
			}
			completion()
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
