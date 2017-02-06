//
//  SearchViewController.swift
//  Cutlines
//
//  Created by John Bruce on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class SearchViewController: UITableViewController {
	
	var searchController: UISearchController!
	var searchResultsController: SearchResultsViewController!
	
	var photoDataSource: PhotoDataSource!
	var imageStore: ImageStore!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		searchResultsController = SearchResultsViewController(imageStore: imageStore, dataSource: photoDataSource)
		searchResultsController.tableView.dataSource = self
		searchResultsController.tableView.delegate = self
		searchResultsController.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
		
		searchController = UISearchController(searchResultsController: searchResultsController)
		searchController.searchResultsUpdater = self
		searchController.dimsBackgroundDuringPresentation = false
		
		definesPresentationContext = true
		
		tableView.tableHeaderView = searchController.searchBar
		tableView.dataSource = self
	}
	
	private func readyForSearch() -> Bool {
		
		guard searchController.isActive, let text = searchController.searchBar.text, !text.isEmpty else {
			return false
		}
		
		return true
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		
		if readyForSearch() {
			return searchResultsController.results.count
		} else {
			return 0
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
		
		if !readyForSearch() {
			return cell
		}
		
		let result = searchResultsController.results[indexPath.row]
		
		cell.textLabel!.text = result.displayString
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		performSegue(withIdentifier: "showCutlineInfo", sender: searchResultsController.tableView.cellForRow(at: indexPath))
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		switch segue.identifier! {
			
		case "showCutlineInfo":
			if let cell = sender as? UITableViewCell,
				let selectedIndexPath =
				self.searchResultsController.tableView.indexPath(for: cell) {
				
				let photo = self.searchResultsController.results[selectedIndexPath.row].photo
				let cutlineInfoController = segue.destination as! CutlineInfoViewController
				
				cutlineInfoController.photo = photo
				cutlineInfoController.photoDataSource = self.photoDataSource
				cutlineInfoController.imageStore = self.imageStore
				cutlineInfoController.animatedFlip = true
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
		
		searchResultsController.results = photos.map { return SearchResult(photo: $0, searchTerm: searchTerm) }
		
		searchResultsController.tableView.reloadData()
	}
}
