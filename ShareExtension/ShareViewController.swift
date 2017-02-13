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
	
	var imageURL: NSURL?
	
	override func viewDidLoad() {
		
		let extensionItem = extensionContext?.inputItems.first as! NSExtensionItem
		let itemProvider = extensionItem.attachments?.first as! NSItemProvider
		let imageUTI = String(kUTTypeImage)
		
		if itemProvider.hasItemConformingToTypeIdentifier(imageUTI) {
			
			itemProvider.loadItem(forTypeIdentifier: imageUTI, options: nil,
				completionHandler: { (item, error) -> Void in
					
					self.imageURL = item as? NSURL
			})
		} else {
			print("error")
		}
	}

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
		
		guard let imageURL = imageURL as? URL else {
			return
		}
		
		let imageData: Data
		do
		{
			try imageData = Data(contentsOf: imageURL)
		} catch {
			print("Error loading image from imageURL \(imageURL.path) error: \(error)")
			return
		}
		
		// TODO: Figure out how to get the PHAsset for this URL
	//	let results = PHAsset.fetchAssets(withALAssetURLs: [imageURL], options: nil)
		
	//	if results.count == 1, let asset = results.firstObject {
			
			let options = PHImageRequestOptions()
			options.isNetworkAccessAllowed = true
			options.version = .current
			
			let encoding = String.Encoding.utf8
			
	//		PHImageManager.default().requestImageData(for: asset, options: options) {
	//			(data, dataUTI, orientation, info) -> Void in
				
				guard
					//let imageData = data,
					let appGroupURL = AppGroupURL else {
					return
				}
				
				// Create a parent folder to hold each file (caption, image data, and assetURL) for the photo
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
				
				// Also save the URL so we can load the PHAsset later on
				let url = sharedPhotoURL.appendingPathComponent(SharedPhotoURLSuffix)
				do {
					try imageURL.absoluteString.write(to: url, atomically: true, encoding: encoding)
				} catch {
					print("Caption was unable to be written to \(url.absoluteString) error: \(error)")
				}
		
				// TODO: Also figure out a nice way to call this even if we error out
				// Inform the host that we're done, so it un-blocks its UI.
				self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
		//	}
		//}
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

}
