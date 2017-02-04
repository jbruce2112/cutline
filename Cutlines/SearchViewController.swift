//
//  SearchViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit


fileprivate struct SearchResult {
	
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

class SearchViewController: UITableViewController {
	
	let searchController = UISearchController(searchResultsController: nil)
	
	var photoDataSource: PhotoDataSource!
	var imageStore: ImageStore!
	
	fileprivate var results = [SearchResult]()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		searchController.searchResultsUpdater = self
		searchController.dimsBackgroundDuringPresentation = false
		definesPresentationContext = true
		tableView.tableHeaderView = searchController.searchBar
		
		tableView.dataSource = self
	}
	
	fileprivate func readyForSearch() -> Bool {
		
		guard searchController.isActive, let text = searchController.searchBar.text, !text.isEmpty else {
			return false
		}
		
		return true
	}
	
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		
		if readyForSearch() {
			return results.count
		} else {
			return 0
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
		
		if !readyForSearch() {
			return cell
		}
		
		let result = results[indexPath.row]
		
		cell.textLabel!.text = result.displayString
		
		return cell
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		switch segue.identifier! {
			
		case "showCutlineInfo":
			
			if let selectedIndexPath =
				tableView.indexPathsForSelectedRows?.first {
				
				let photo = photoDataSource.photos[selectedIndexPath.row]
				let cutlineInfoController = segue.destination as! CutlineInfoViewController
				
				cutlineInfoController.photo = photo
				cutlineInfoController.photoDataSource = photoDataSource
				cutlineInfoController.imageStore = imageStore
			}
		default:
			preconditionFailure("Unexpected segue identifier")
		}
	}
	
}

extension SearchViewController: UISearchResultsUpdating {
	
	func updateSearchResults(for searchController: UISearchController) {
		
		let searchTerm = searchController.searchBar.text!.lowercased()
		
		let photos = photoDataSource.photos.filter { photo in
			
			return photo.caption!.lowercased().contains(searchTerm)
		}
		
		results = photos.map { return SearchResult(photo: $0, searchTerm: searchTerm) }
		
		tableView.reloadData()
	}
}
