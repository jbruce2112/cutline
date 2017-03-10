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
	
	var photoManager = PhotoManager()
	
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
		
		// If the provider didn't give us a UIImage, read the contents of the URL we were given
		if image == nil {
			
			// Note: The URL from the image is not an ALAsset URL, nor is it possible to
			// reliably derive one from it, since the NSItemProvider may be from any image source.
			// So, we just save the image contents to disk along with the caption and load them up when the app starts again.
			image = UIImage(contentsOfFile: imageURL.path)
			
			if image == nil {
				
				Log("Error loading image from imageURL \(imageURL.path)")
				
				// Inform the host that we're done when exiting this function, so it un-blocks its UI.
				self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
				return
			}
		}
		
		photoManager.setupNoSync {
			
			self.photoManager.add(image: self.image, caption: self.contentText, dateTaken: Date(), qos: .userInteractive) { result in
				
				switch result {
					
				case .success:
					Log("Image added to photomanager from extension successfully")
				case let .failure(error):
					Log("Failed to add image to photomanager from extension \(error)")
				}
				
				// Inform the host that we're done when exiting this function, so it un-blocks its UI.
				//
				// The extension seems to be deallocated after this,
				// so we can't just call this outside this completion handler
				self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
			}
		}
    }
}
