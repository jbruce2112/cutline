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
    
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
		
		self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
		
		guard let imageURLString = imageURL?.absoluteString else {
			return
		}
		
		guard let appGroupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.bruce32.Cutlines")?.appendingPathComponent("Shared") else {
			return
		}
		
		do {
			try FileManager.default.createDirectory(at: appGroupDir, withIntermediateDirectories: true, attributes: nil)
		} catch {
			print("Error creating app group dir \(appGroupDir.absoluteString) error: \(error)")
		}
		
		let contents = imageURLString + "\n" + contentText
		let contentsData = (contents as NSString).data(using: String.Encoding.utf8.rawValue)
		let filePath = appGroupDir.appendingPathComponent(UUID().uuidString).absoluteString
		
		let result = FileManager.default.createFile(atPath: filePath, contents: contentsData, attributes: nil)
		
		if result
		{
			print("File successfully written to \(filePath)")
		}
		else
		{
			print("File was unable to be written to \(filePath)")
		}
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

}
