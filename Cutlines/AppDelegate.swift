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
	
	private let photoDataSource = PhotoDataSource()
	private let imageStore = ImageStore()
	private let cloudManager = CloudKitManager()
	private let photoManager = PhotoManager()
	
	let defaults = UserDefaults.standard
	
	private var tabBarController: UITabBarController!
	private var navigationControllers: [UINavigationController]!
	private var cutlinesViewController: CutlinesViewController!

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		
		tabBarController = window!.rootViewController as! UITabBarController
		navigationControllers = tabBarController.viewControllers! as! [UINavigationController]
		
		cutlinesViewController = navigationControllers[0].viewControllers.first! as! CutlinesViewController
		let searchViewController = navigationControllers[1].viewControllers.first! as! SearchViewController
		
		// Inject our objects into the managers and initial view controllers
		cloudManager.delegate = photoManager
		cloudManager.photoDataSource = photoDataSource
		cloudManager.imageStore = imageStore
		
		photoManager.cloudManager = cloudManager
		photoManager.photoDataSource = photoDataSource
		photoManager.imageStore = imageStore
		
		cutlinesViewController.photoManager = photoManager
		searchViewController.photoManager = photoManager
		
		cutlinesViewController.photoDataSource = photoDataSource
		searchViewController.photoDataSource = photoDataSource
		
		// Tell the photo manager to set everything up
		photoManager.setup()
		
		// Listen for push events
		application.registerForRemoteNotifications()
		
		// Set initial theme
		setTheme()
		
		return true
	}
	
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any],
	                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		
		let dict = userInfo as! [String: NSObject]
		let notification = CKNotification(fromRemoteNotificationDictionary: dict)
		if notification.subscriptionID == cloudManager.subscriptionID {
			
			cloudManager.fetchChanges {
				
				completionHandler(UIBackgroundFetchResult.newData)
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
		// the share extension on a background thread.
		DispatchQueue.global(qos: .background).async {
			
			self.checkAppGroupForPhotos()
		}
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}
	
	func setTheme() {
		
		// We're settings these properties in the AppDelegate since it already knows
		// about the navigation and tab controllers, and we don't currently have any
		// custom classes to implement their own viewWillAppear()/setTheme() behavior
		tabBarController.tabBar.setTheme()
		
		for controller in navigationControllers {
			controller.navigationBar.setTheme()
		}
	}
	
	// Check for photos given to us by the share extension
	// by checking for files in our shared group folder.
	// TODO: Once our logic is moved to its on lib, we can remove this
	private func checkAppGroupForPhotos() {
		
		if !FileManager.default.fileExists(atPath: appGroupURL.path) {
			return
		}
		
		let subPaths: [String]
		do {
			try subPaths = FileManager.default.contentsOfDirectory(atPath: appGroupURL.path)
		} catch {
			print("Unable to read contents of \(appGroupURL) - error: \(error)")
			return
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
					try FileManager.default.removeItem(atPath: fullSubPathURL.path)
				} catch {
					print("Unable to remove photo dir path \(fullSubPathURL) from app group dir: \(error)")
				}
			case let .failure(error):
				print("Cutline save failed with error: \(error)")
			}
		}
	}
}
