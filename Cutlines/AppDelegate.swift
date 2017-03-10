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
	
	private let photoManager = PhotoManager()
		
	private var tabBarController: UITabBarController!
	private var navigationControllers: [UINavigationController]!
	private var cutlinesViewController: CutlinesViewController!

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		
		tabBarController = window!.rootViewController as! UITabBarController
		navigationControllers = tabBarController.viewControllers! as! [UINavigationController]
		
		cutlinesViewController = navigationControllers[0].viewControllers.first! as! CutlinesViewController
		let searchViewController = navigationControllers[1].viewControllers.first! as! SearchViewController
		
		// Inject the manager into the initial view controllers
		cutlinesViewController.photoManager = photoManager
		searchViewController.photoManager = photoManager
				
		// Tell the photo manager to set everything up
		// required for cloud communication, syncing and storage
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
		if notification.subscriptionID == photoManager.cloudManager.subscriptionID {
			
			photoManager.cloudManager.fetchChanges {
				
				completionHandler(UIBackgroundFetchResult.newData)
			}
		}
	}
	
	func application(_ application: UIApplication,
	                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
		
		Log("Failed to register for notifications with \(error)")
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
		photoManager.cloudManager.saveSyncState()
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state;
		// here you can undo many of the changes made on entering the background.
		
		cutlinesViewController.refresh()
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application
		// was inactive. If the application was previously in the background, optionally refresh the user interface.
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
}
