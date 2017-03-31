//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by John on 2/7/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import MobileCoreServices
import Photos
import Social
import UIKit

class ShareViewController: SLComposeServiceViewController {
	
	var image: UIImage?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		placeholder = captionPlaceholder
	}
	
	override func isContentValid() -> Bool {
		
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
				
				switch item {
					
				case let image as UIImage:
					self.image = image
				case let data as Data:
					self.image = UIImage(data: data)
				case let url as URL:
					self.image = UIImage(contentsOfFile: url.path)
				default:
					break
				}
			}
		}
		
		return image != nil
	}
	
	override func didSelectPost() {
		
		guard let image = self.image else {
			
			log("Unable to load image from extension")
			
			// Inform the host that we're done when exiting this function, so it un-blocks its UI.
			self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
			return
		}
		
		let photoManager = PhotoManager()
		photoManager.setupNoSync {
			
			// Set backgroundUpload = true so we return control to the host app
			// as soon as we add the photo to our local store. The cloud upload will continue in the background
			photoManager.add(image: image, caption: self.contentText, dateTaken: Date(), backgroundUpload: true) { result in
				
				switch result {
					
				case .success:
					
					// Save the record zone state in our cache so we don't bother creating it next time
					photoManager.cloudManager.saveSyncState()
					log("Image added to photomanager from extension successfully")
				case let .failure(error):
					log("Failed to add image to photomanager from extension \(error)")
				}
				
				// Inform the host that we're done when exiting this function, so it un-blocks its UI.
				// Note: The extension is deallocated after this, so we can't just call this outside this completion handler
				self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
			}
		}
	}
}
