//
//  SearchResultsViewController.swift
//  Cutlines
//
//  Created by John Bruce on 2/5/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

struct SearchResult {
	
	let photo: Photo!
	let searchTerm: String!
	
	let displayString: String!
	
	init(photo: Photo, searchTerm: String) {
		
		self.photo = photo
		self.searchTerm = searchTerm
		
		let captionNoNewline = photo.caption!.replacingOccurrences(of: "\n", with: " ")
		let captionLowercased = captionNoNewline.lowercased()
		
		let matchStartIndex = captionLowercased.range(of: searchTerm)!.lowerBound
		
		var displayStart = captionLowercased.startIndex
		
		let leadingPaddingChars = 20
		if captionLowercased.distance(from: captionLowercased.startIndex, to: matchStartIndex) > leadingPaddingChars {
			displayStart = captionLowercased.index(matchStartIndex, offsetBy: -1 * leadingPaddingChars / 2)
		}
		
		displayString = captionNoNewline.substring(from: displayStart)
	}
}

class SearchResultsViewController: UITableViewController, UIViewControllerPreviewingDelegate {
	
	var imageStore: ImageStore!
	var photoDataSource: PhotoDataSource!
	
	var results = [SearchResult]()
	
	
	
	init(imageStore: ImageStore, dataSource: PhotoDataSource) {
		super.init(style: .plain)
		
		self.imageStore = imageStore
		self.photoDataSource = dataSource
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		registerForPreviewing(with: self, sourceView: tableView)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	// MARK: - 3D Touch Support
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
		
		// TODO: This is horribly jank, but our storyboard and navController properties are always nil otherwise (?)
		let navController = (tableView.delegate as! UIViewController).navigationController
		navController?.pushViewController(viewControllerToCommit, animated: true)
	}
	
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
		
		guard let selectedIndexPath = tableView.indexPathForRow(at: location) else {
			return nil
		}
		
		// TODO: This is horribly jank, but our storyboard and navController properties are always nil otherwise (?)
		let navController = (tableView.delegate as! UIViewController).navigationController
		let infoController = navController?.storyboard?.instantiateViewController(withIdentifier: "CutlineInfoViewController") as! CutlineInfoViewController
		
		infoController.photo = results[selectedIndexPath.row].photo
		infoController.imageStore = imageStore
		infoController.photoDataSource = photoDataSource
		
		return infoController
	}
}
