//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by John Bruce on 2/7/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit
import Social
import MobileCoreServices
import Photos

class ShareViewController: SLComposeServiceViewController {
	
	var imageURL: URL!
	
	override func viewDidLoad() {
		
		placeholder = "Enter your photo caption"
		
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
			
			itemProvider.loadItem(forTypeIdentifier: imageUTI, options: nil) {
				(item, _) -> Void in
				
				guard let url = item as? URL else { return }
				self.imageURL = url
			}
		}
		
		return imageURL != nil
    }

    override func didSelectPost() {
        // This is called after the user selects Post.
		
		defer {
			// Inform the host that we're done when exiting this function, so it un-blocks its UI.
			self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
		}
		
		guard
			let appGroupURL = AppGroupURL else {
			return
		}
		
		// Note: NSItemProvider only hands out images, not PHAssets, (since it may be from any image source).
		// The URL from the image is not an ALAsset URL either, nor is it possible to reliably derive one from it.
		// So, we just save the image contents to disk along with the caption and load them up when the app
		// starts again.
		let imageData: Data
		do
		{
			try imageData = Data(contentsOf: imageURL)
		} catch {
			print("Error loading image from imageURL \(imageURL.path) error: \(error)")
			return
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
		
		let newImageURL = sharedPhotoURL.appendingPathComponent(SharedPhotoImageSuffix)
		do {
			try imageData.write(to: newImageURL)
		} catch {
			print("File was unable to be written to \(newImageURL.absoluteString) error: \(error)")
		}
		
		let captionURL = sharedPhotoURL.appendingPathComponent(SharedPhotoCaptionSuffix)
		do {
			try self.contentText.write(to: captionURL, atomically: true, encoding: encoding)
		} catch {
			print("Caption was unable to be written to \(captionURL.absoluteString) error: \(error)")
		}
    }
}
