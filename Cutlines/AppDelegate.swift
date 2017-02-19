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
	
	var tabBarController: UITabBarController!
	var navigationControllers: [UINavigationController]!
	var cutlinesViewController: CutlinesViewController!
	
	fileprivate var darkModeEnabled = false

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		
		tabBarController = window!.rootViewController as! UITabBarController
		navigationControllers = tabBarController.viewControllers! as! [UINavigationController]
		
		cutlinesViewController = navigationControllers[0].viewControllers.first! as! CutlinesViewController
		let searchViewController = navigationControllers[1].viewControllers.first! as! SearchViewController
		
		cutlinesViewController.photoDataSource = photoDataSource
		searchViewController.photoDataSource = photoDataSource
		
		cutlinesViewController.imageStore = imageStore
		searchViewController.imageStore = imageStore
		
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
	
	func toggleDarkMode(_ enable: Bool) {
		
		tabBarController.tabBar.barStyle = enable ? .black : .default
		
		for controller in navigationControllers {
			controller.navigationBar.barStyle = enable ? .black : .default
		}
		
		darkModeEnabled = enable
	}
	
	private func checkAppGroupForPhotos() -> Int {
		
		var photosAdded = 0
		
		guard let appGroupURL = AppGroupURL else {
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
			
			let imagePath = fullSubPathURL.appendingPathComponent(SharedPhotoImageSuffix).path
			let captionPath = fullSubPathURL.appendingPathComponent(SharedPhotoCaptionSuffix).path
			
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

@objc
class Theme: NSObject {
	
	var backgroundColor: UIColor!
	var textColor: UIColor!
}

extension UIViewController {
	
	@objc
	func setTheme() {
		setTheme(view.theme())
	}
	
	@objc
	func setTheme(_ theme: Theme) {
		view.setTheme(theme)
	}
}

extension UIView {
	
	@objc
	func setTheme() {
		setTheme(theme())
	}
	
	@objc
	func setTheme(_ theme: Theme) {
		backgroundColor = theme.backgroundColor
	}
	
	func theme() -> Theme {
		
		let theme = Theme()
		if (UIApplication.shared.delegate as! AppDelegate).darkModeEnabled {
			theme.backgroundColor = .black
			theme.textColor = UIColor(colorLiteralRed: 0, green: 122.0/255, blue: 255, alpha: 1)
		} else {
			theme.backgroundColor = .white
			theme.textColor = .black
		}
		
		return theme
	}
}
