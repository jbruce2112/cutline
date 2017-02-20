//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by John Bruce on 2/7/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import MobileCoreServices
import Photos
import Social
import UIKit

class ShareViewController: SLComposeServiceViewController {
	
	var imageURL: URL!
	var image: UIImage!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		placeholder = captionPlaceholder
	}

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
		
		guard
			let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
			let itemProvider = extensionItem.attachments?.first as? NSItemProvider else {
				return false
		}
		
		if extensionItem.attachments?.count != 1 {
			return false
		}
		
		let imageUTI = String(kUTTypeImage)
		if itemProvider.hasItemConformingToTypeIdentifier(imageUTI) {
			
			itemProvider.loadItem(forTypeIdentifier: imageUTI, options: nil) { (item, _) in
				
				if let image = item as? UIImage {
					
					self.image = image
				} else if let url = item as? URL {
					
					self.imageURL = url
				}
			}
		}
		
		return imageURL != nil || image != nil
    }

    override func didSelectPost() {
        // This is called after the user selects Post.
		
		defer {
			// Inform the host that we're done when exiting this function, so it un-blocks its UI.
			self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
		}
		
		let imageData: Data
		
		// If the provider gave us a UIImage, try to convert it to a Data
		if image != nil, let data = UIImageJPEGRepresentation(image, 1.0) {
			
			imageData = data
		} else {
			
			// Otherwise, read the contents of the URL we were given
			do {
				// Note: The URL from the image is not an ALAsset URL, nor is it possible to
				// reliably derive one from it, since the NSItemProvider may be from any image source.
				// So, we just save the image contents to disk along with the caption and load them up when the app starts again.
				try imageData = Data(contentsOf: imageURL)
			} catch {
				print("Error loading image from imageURL \(imageURL.path) error: \(error)")
				return
			}
		}
		
		let encoding = String.Encoding.utf8
		
		// Create a parent folder to hold each file (caption and image data) for the photo
		let sharedPhotoURL = appGroupURL.appendingPathComponent(UUID().uuidString)
		
		do {
			try FileManager.default.createDirectory(at: sharedPhotoURL,
			                                        withIntermediateDirectories: true, attributes: nil)
		} catch {
			print("Error creating parent dir for shared photo in app group error: \(error)")
		}
		
		let newImageURL = sharedPhotoURL.appendingPathComponent(sharedPhotoImageSuffix)
		do {
			try imageData.write(to: newImageURL)
		} catch {
			print("File was unable to be written to \(newImageURL.absoluteString) error: \(error)")
		}
		
		let captionURL = sharedPhotoURL.appendingPathComponent(sharedPhotoCaptionSuffix)
		do {
			try self.contentText.write(to: captionURL, atomically: true, encoding: encoding)
		} catch {
			print("Caption was unable to be written to \(captionURL.absoluteString) error: \(error)")
		}
    }
}
