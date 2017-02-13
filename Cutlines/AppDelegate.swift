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
		
		checkAppGroupForPhotos()
		
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
		
		guard let appGroupURL = AppGroupURL else {
			return
		}
		
		let subPaths: [String]
		do {
			try subPaths = FileManager.default.contentsOfDirectory(atPath: appGroupURL.path)
		} catch {
			print("Unable to read contents of \(AppGroupURL) - error: \(error)")
			return
		}
		
		let encoding = String.Encoding(rawValue: String.Encoding.utf8.rawValue)
		
		for subpath in subPaths {
			
			let fullSubPathURL = appGroupURL.appendingPathComponent(subpath)
			
			if !fullSubPathURL.hasDirectoryPath {
				continue
			}
			
			//let urlPath = fullSubPathURL.appendingPathComponent(SharedPhotoURLSuffix).path
			let imagePath = fullSubPathURL.appendingPathComponent(SharedPhotoImageSuffix).path
			let captionPath = fullSubPathURL.appendingPathComponent(SharedPhotoCaptionSuffix).path
			
			/*
			let urlString: String
			do {
				try urlString = String(contentsOfFile: urlPath, encoding: encoding)
			} catch {
				print("Couldn't read file at \(urlPath), error: \(error)")
				continue
			}
			*/
			
			let caption: String
			do {
				try caption = String(contentsOfFile: captionPath, encoding: encoding)
			} catch {
				print("Couldn't read file at \(captionPath), error: \(error)")
				continue
			}
			
			guard
				let imageURL = URL(string: imagePath),
				let image = UIImage(contentsOfFile: imageURL.absoluteString) else {
				return
			}
			
			/*
			guard let assetURL = URL(string: urlString) else {
				return
			}
			*/
			
			// TODO: figure out how to get a PHAsset from the URL the extension api gives us.
			// It does NOT work with the ALAssetURL fetch api.
			//let results = PHAsset.fetchAssets(withALAssetURLs: [assetURL], options: nil)
			
			//if results.count == 1, let asset = results.firstObject {
			
				let id = UUID().uuidString
				
				self.imageStore.setImage(image, forKey: id)
			
				let dateTaken = Date()
				self.photoDataSource.addPhoto(id: id, caption: caption, dateTaken: dateTaken) {
					(result) in
					
					switch result {
					case .success:
						do {
							try FileManager.default.removeItem(atPath: fullSubPathURL.path)
						} catch {
							print("Unable to remove photo dir path \(fullSubPathURL.path) from app group dir: \(error)")
						}
					case let .failure(error):
						print("Cutline save failed with error: \(error)")
					}
				}
			//}
		}
	}
}

