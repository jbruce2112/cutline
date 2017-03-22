//
//  SearchResultsViewController.swift
//  Cutline
//
//  Created by John Bruce on 2/5/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

typealias SearchResult = (photo: Photo, searchTerm: String)

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
		// Don't show empty cells
		tableView.tableFooterView = UIView()
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
		
		cell.resultImage = nil
		cell.result = result
		
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
		let photos = photoManager.photoStore.fetch(containing: searchTerm)
		
		// Create search results out of all of them
		results = photos.map { SearchResult(photo: $0, searchTerm: searchTerm) }
		
		tableView.reloadData()
		
		searchTermDelegate?.didPerformSearch(withTerm: searchTerm)
	}
}

// MARK: - 3D Touch Support
extension SearchResultsViewController: UIViewControllerPreviewingDelegate {
	
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
		
		let editController = viewControllerToCommit as! EditViewController
		editController.toolbar.isHidden = false
		
		presentingViewController?.navigationController?.pushViewController(editController, animated: true)
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
		editController.previewer = self
		
		// Make sure the toolbar is set
		editController.loadViewIfNeeded()
		
		editController.toolbar.isHidden = true
		
		return editController
	}
}
