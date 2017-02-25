//
//  AppDelegate.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import CloudKit
import Photos
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	
	let photoDataSource = PhotoDataSource()
	let imageStore = ImageStore()
	let cloudManager = CloudKitManager()
	
	let defaults = UserDefaults.standard
	
	private var tabBarController: UITabBarController!
	private var navigationControllers: [UINavigationController]!
	private var cutlinesViewController: CutlinesViewController!

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		
		tabBarController = window!.rootViewController as! UITabBarController
		navigationControllers = tabBarController.viewControllers! as! [UINavigationController]
		
		cutlinesViewController = navigationControllers[0].viewControllers.first! as! CutlinesViewController
		let searchViewController = navigationControllers[1].viewControllers.first! as! SearchViewController
		
		cutlinesViewController.photoDataSource = photoDataSource
		searchViewController.photoDataSource = photoDataSource
		cloudManager.photoDataSource = photoDataSource
		
		cutlinesViewController.imageStore = imageStore
		searchViewController.imageStore = imageStore
		cloudManager.imageStore = imageStore
		
		application.registerForRemoteNotifications()
		
		// Set initial theme
		setDarkMode(defaults.bool(forKey: Key.darkMode.rawValue))
		
		return true
	}
	
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any],
	                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		
		let dict = userInfo as! [String: NSObject]
		let notification = CKNotification(fromRemoteNotificationDictionary: dict)
		if notification.subscriptionID == cloudManager.subscriptionID {
			
			cloudManager.fetchChanges {
				
				completionHandler(UIBackgroundFetchResult.newData)
				
				DispatchQueue.main.async {
					self.cutlinesViewController.refresh()
				}
			}
		}
	}
	
	func application(_ application: UIApplication,
	                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
		
		print("Failed to register for notifications with \(error)")
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state.
		// This can occur for certain types of temporary interruptions (such as an 
		// incoming phone call or SMS message) or when the user quits the application
		// and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate
		// graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers,
		// and store enough application state information to restore your application to its
		// current state in case it is terminated later. If your application supports 
		// background execution, this method is called instead of applicationWillTerminate: when the user quits.
		cloudManager.saveSyncState()
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state;
		// here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application
		// was inactive. If the application was previously in the background, optionally refresh the user interface.
		
		
		// Kick off a check for any photos that were added through
		// a share extension on a background thread.
		// Refresh the main collection view if any were found.
		DispatchQueue.global(qos: .background).async {
			
			let photosAdded = self.checkAppGroupForPhotos()
			
			if photosAdded == 0 {
				return
			}
			
			DispatchQueue.main.async {
				self.cutlinesViewController.refresh()
			}
		}
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}
	
	func setDarkMode(_ enable: Bool) {
		
		// We're settings these properties in the AppDelegate since it already knows
		// about the navigation and tab controllers, and we don't currently have any
		// custom classes to implement their own viewWillAppear()/setTheme() behavior
		tabBarController.tabBar.barStyle = enable ? .black : .default
		
		for controller in navigationControllers {
			controller.navigationBar.barStyle = enable ? .black : .default
		}
		
		defaults.set(enable, forKey: Key.darkMode.rawValue)
	}
	
	private func checkAppGroupForPhotos() -> Int {
		
		var photosAdded = 0
		
		if !FileManager.default.fileExists(atPath: appGroupURL.path) {
			return 0
		}
		
		let subPaths: [String]
		do {
			try subPaths = FileManager.default.contentsOfDirectory(atPath: appGroupURL.path)
		} catch {
			print("Unable to read contents of \(appGroupURL) - error: \(error)")
			return 0
		}
		
		let encoding = String.Encoding(rawValue: String.Encoding.utf8.rawValue)
		
		for subPath in subPaths {
			
			let fullSubPathURL = appGroupURL.appendingPathComponent(subPath)
			
			if !fullSubPathURL.hasDirectoryPath {
				continue
			}
			
			let imagePath = fullSubPathURL.appendingPathComponent(sharedPhotoImageSuffix).path
			let captionPath = fullSubPathURL.appendingPathComponent(sharedPhotoCaptionSuffix).path
			
			let caption: String
			do {
				try caption = String(contentsOfFile: captionPath, encoding: encoding)
			} catch {
				print("Couldn't read caption file at \(captionPath), error: \(error)")
				continue
			}
			
			guard
				let imageURL = URL(string: imagePath),
				let image = UIImage(contentsOfFile: imageURL.absoluteString) else {
				continue
			}
			
			let id = UUID().uuidString
			
			self.imageStore.setImage(image, forKey: id)
			
			// Just set dateTaken to now(), since we dont' have the PHAsset in this context
			let dateTaken = Date()
			let result = self.photoDataSource.addPhoto(id: id, caption: caption, dateTaken: dateTaken)
			
			switch result {
			case .success:
				do {
					photosAdded += 1
					try FileManager.default.removeItem(atPath: fullSubPathURL.path)
				} catch {
					print("Unable to remove photo dir path \(fullSubPathURL) from app group dir: \(error)")
				}
			case let .failure(error):
				print("Cutline save failed with error: \(error)")
			}
		}
		
		return photosAdded
	}
}
