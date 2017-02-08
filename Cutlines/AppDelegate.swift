//
//  AppDelegate.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit
import Photos

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	
	let photoDataSource = PhotoDataSource()
	let imageStore = ImageStore()

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		
		let tabBarController = window!.rootViewController as! UITabBarController
		let navigationControllers = tabBarController.viewControllers! as! [UINavigationController]
		
		let cutlinesController = navigationControllers[0].viewControllers.first! as! CutlinesViewController
		let searchController = navigationControllers[1].viewControllers.first! as! SearchViewController
		
		cutlinesController.photoDataSource = photoDataSource
		searchController.photoDataSource = photoDataSource
		
		cutlinesController.imageStore = imageStore
		searchController.imageStore = imageStore
		
		// Override point for customization after application launch.
		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}
	
	private func checkAppGroupForPhotos() {
		
		guard let appGroupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.bruce32.Cutlines")?.appendingPathComponent("Shared") else {
			return
		}
		
		var files = [String]()
		do {
			
			try files = FileManager.default.contentsOfDirectory(atPath: appGroupDir.absoluteString)
		} catch {
			print("Unable to read contents of \(appGroupDir) - error: \(error)")
		}
		
		let encoding = String.Encoding(rawValue: String.Encoding.utf8.rawValue)
		
		for file in files {
			
			var fileContents: String
			
			do {
				
				try fileContents = String(contentsOfFile: file, encoding: encoding)
			} catch {
				print("Couldn't read file at \(file), error: \(error) continuing")
				continue
			}
			
			guard
				let indexOfNewline = fileContents.characters.index(of: "\n"),
				let fileURL = URL(string: fileContents.substring(to: indexOfNewline)) else {
				continue
			}
			
			let indexAfterNewline = fileContents.characters.index(after: indexOfNewline)
			
			let caption = fileContents.substring(from: indexAfterNewline)
			
			// TODO: use non-deprecated api
			let results = PHAsset.fetchAssets(withALAssetURLs: [fileURL], options: nil)
			
			if results.count == 1, let asset = results.firstObject {
				
				let id = NSUUID().uuidString
				
				let options = PHImageRequestOptions()
				options.isNetworkAccessAllowed = true
				options.version = .current
				
				PHImageManager.default().requestImageData(for: asset, options: options) {
					(data, dataUTI, orientation, info) -> Void in
					
						guard let data = data, let image = UIImage(data: data) else { return }
					
						self.imageStore.setImage(image, forKey: id)
					
						self.photoDataSource.addPhoto(id: id, caption: caption, dateTaken: asset.creationDate!) {
							(result) in
						
							switch result {
							case .success:
								do {
									try FileManager.default.removeItem(atPath: file)
								} catch {
									print("Unable to remove file \(file) from app group dir: \(error)")
								}
							case let .failure(error):
								print("Cutline save failed with error: \(error)")
							}
						}
				}
			} else {
				print("Error fetching asset URL \(fileURL)")
			}
		}
	}
}

