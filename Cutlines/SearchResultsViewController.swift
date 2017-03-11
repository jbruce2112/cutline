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
	
	// TODO: comment
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

protocol SearchTermDelegate: class {
	
	func didPerformSearch(withTerm searchTerm: String)
}

class SearchResultsViewController: UITableViewController {
	
	// MARK: Properties
	var results = [SearchResult]()
	
	var searchController: UISearchController!
	var photoManager: PhotoManager!
	
	weak var searchTermDelegate: SearchTermDelegate?
	
	init() {
		super.init(style: .plain)
		
		searchController = UISearchController(searchResultsController: self)
		searchController.searchResultsUpdater = self
		searchController.dimsBackgroundDuringPresentation = false
		
		tableView.dataSource = self
		tableView.delegate = self
		tableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
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
	
	// MARK: TableView delegate functions
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		
		return readyForSearch() ? results.count : 0
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		
		return 80.0
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as! SearchResultCell
		
		if !readyForSearch() {
			return cell
		}
		
		let result = results[indexPath.row]
		
		cell.resultText = result.displayString
		
		photoManager.thumbnail(for: result.photo, withSize: cell.frame.size) { thumbnail in
			
			cell.resultImage = thumbnail
			cell.setNeedsLayout()
			cell.layoutIfNeeded()
		}
		
		cell.setTheme()
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		guard
			let cell = tableView.cellForRow(at: indexPath),
			let selectedIndex =	self.tableView.indexPath(for: cell) else {
				return
		}
		
		let photo = results[selectedIndex.row].photo
		
		let editViewController =
			presentingViewController?.storyboard?.instantiateViewController(withIdentifier: "EditViewController") as! EditViewController
		
		editViewController.photo = photo
		editViewController.photoManager = photoManager
		
		presentingViewController?.navigationController?.pushViewController(editViewController, animated: true)
	}
	
	// MARK: Private functions
	private func readyForSearch() -> Bool {
		
		if !searchController.isActive {
			return false
		} else {
			
			let text = searchController.searchBar.text
			return text != nil && !text!.isEmpty
		}
	}
}

// MARK: UISearchResultsUpdating conformance
extension SearchResultsViewController: UISearchResultsUpdating {
	
	func updateSearchResults(for searchController: UISearchController) {
		
		let searchTerm = searchController.searchBar.text!.lowercased()
		
		// Get all photos containing the searchTerm
		let photos = photoManager.photoDataSource.fetch(containing: searchTerm)
		
		// Create search results out of all of them
		results = photos.map { SearchResult(photo: $0, searchTerm: searchTerm) }
		
		tableView.reloadData()
		
		searchTermDelegate?.didPerformSearch(withTerm: searchTerm)
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
		
		let editController = presentingViewController?.storyboard?.instantiateViewController(
																	withIdentifier: "EditViewController") as! EditViewController
		
		let photo = results[selectedIndexPath.row].photo
		editController.photo = photo
		editController.photoManager = photoManager
		
		return editController
	}
}
