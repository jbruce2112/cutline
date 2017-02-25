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

class SearchResultsViewController: UITableViewController {
	
	var results = [SearchResult]()
	
	fileprivate var photoManager: PhotoManager!
	
	init(photoManager: PhotoManager) {
		super.init(style: .plain)
		
		self.photoManager = photoManager
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
}

// MARK: - 3D Touch Support
extension SearchResultsViewController: UIViewControllerPreviewingDelegate {
	
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
		
		presentingViewController?.navigationController?.pushViewController(viewControllerToCommit, animated: true)
	}
	
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
		
		guard let selectedIndexPath = tableView.indexPathForRow(at: location) else {
			return nil
		}
		
		let infoController = presentingViewController?.storyboard?.instantiateViewController(
																	withIdentifier: "CutlineInfoViewController") as! CutlineInfoViewController
		
		let photo = results[selectedIndexPath.row].photo
		infoController.photo = photo
		infoController.photoManager = photoManager
		
		return infoController
	}
}
