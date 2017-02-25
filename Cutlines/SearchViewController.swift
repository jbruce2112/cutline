//
//  SearchViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class SearchViewController: UITableViewController {
	
	// MARK: Properties
	var photoDataSource: PhotoDataSource!
	var photoManager: PhotoManager!
	
	private var searchController: UISearchController!
	fileprivate var searchResultsController: SearchResultsViewController!
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		searchResultsController = SearchResultsViewController(photoManager: photoManager)
		searchResultsController.tableView.dataSource = self
		searchResultsController.tableView.delegate = self
		searchResultsController.tableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
		
		searchController = UISearchController(searchResultsController: searchResultsController)
		searchController.searchResultsUpdater = self
		searchController.dimsBackgroundDuringPresentation = false
		
		definesPresentationContext = true
		
		tableView.tableHeaderView = searchController.searchBar
		tableView.dataSource = self
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		let barStyle: UIBarStyle = theme.backgroundColor == UIColor.black ? .black : .default
		searchController.searchBar.barStyle = barStyle
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		
		return readyForSearch() ? searchResultsController.results.count : 0
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
		
		if !readyForSearch() {
			return cell
		}
		
		let result = searchResultsController.results[indexPath.row]
		
		cell.textLabel!.text = result.displayString
		cell.imageView?.image = photoManager.image(for: result.photo)
		
		cell.setTheme()
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		performSegue(withIdentifier: "showCutlineInfoAnimated", sender: searchResultsController.tableView.cellForRow(at: indexPath))
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		switch segue.identifier! {
			
		case "showCutlineInfoAnimated":
			
			guard
				let cell = sender as? UITableViewCell,
				let selectedIndex =	self.searchResultsController.tableView.indexPath(for: cell) else {
					return
			}
			
			let photo = self.searchResultsController.results[selectedIndex.row].photo
			let cutlineInfoController = segue.destination as! CutlineInfoViewController
			
			cutlineInfoController.photo = photo
			cutlineInfoController.photoManager = photoManager
			cutlineInfoController.animated = true
			
		case "showSettings":
			break
		default:
			preconditionFailure("Unexpected segue identifier")
		}
	}
	
	// MARK: Private functions
	private func readyForSearch() -> Bool {
		
		guard
			searchController.isActive, let text = searchController.searchBar.text, !text.isEmpty else {
				return false
		}
		
		return true
	}
}

// MARK: UISerachResultsUpdating conformance
extension SearchViewController: UISearchResultsUpdating {
	
	func updateSearchResults(for searchController: UISearchController) {
		
		let searchTerm = searchController.searchBar.text!.lowercased()
		
		// Get all photos containing the searchTerm
		let photos = photoDataSource.photos.filter { $0.caption!.lowercased().contains(searchTerm) }
		
		// Create search results out of all of them
		searchResultsController.results = photos.map { return SearchResult(photo: $0, searchTerm: searchTerm) }
		
		searchResultsController.tableView.reloadData()
	}
}
