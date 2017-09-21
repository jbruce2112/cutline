//
//  SearchViewController.swift
//  Cutlines
//
//  Created by John on 1/30/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class SearchViewController: UITableViewController {
	
	// MARK: Properties
	var photoManager: PhotoManager!
	
	private var resultsViewController = SearchResultsViewController()
	
	private var recentSearches = [String]()
	
	private let recentSearchTermLimit = 5
	private var lastSearchTerm: String?
	
	private let recentSearchesArchive: String = {
		
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		return cacheDir.appendingPathComponent("recentSearches.archive").path
	}()
	
	private var searchController: UISearchController!
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		definesPresentationContext = true
		
		searchController = UISearchController(searchResultsController: resultsViewController)
		searchController.searchResultsUpdater = resultsViewController
		searchController.dimsBackgroundDuringPresentation = false
		
		resultsViewController.photoManager = photoManager
		resultsViewController.searchController = searchController
		
		// Integrate the searchController into
		//the navigationController if we're on iOS 11+
		if #available(iOS 11.0, *) {
			navigationItem.searchController = searchController
			
			navigationItem.searchController?.hidesNavigationBarDuringPresentation = false
			navigationItem.hidesSearchBarWhenScrolling = false
		} else {
			tableView.tableHeaderView = searchController.searchBar
		}
		
		tableView.cellLayoutMarginsFollowReadableWidth = true
		
		// Don't show empty cells
		tableView.tableFooterView = UIView()
		
		tableView.dataSource = self
		
		resultsViewController.searchController.delegate = self
		resultsViewController.searchTermDelegate = self
		
		recentSearches = loadRecent()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
		// Since this viewController overlays us,
		// we need to call setTheme() on it as well
		resultsViewController.setTheme()
	}
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		searchController.searchBar.setTheme()
		
		// force the section headers to refresh
		tableView.reloadSections(IndexSet(integer: 0), with: .none)
		
		tableView.backgroundView = UIView()
		tableView.backgroundView?.setTheme()
	}
	
	override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
		tableView.reloadData()
	}
	
	func saveRecent() {
		
		NSKeyedArchiver.archiveRootObject(recentSearches, toFile: recentSearchesArchive)
		log("Recent searches saved")
	}
	
	// MARK: UITableViewDataSource functions
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		
		return recentSearches.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
		
		cell.textLabel!.text = recentSearches[indexPath.row]
		cell.setTheme()
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		
		return section == 0 ? "Recent Searches" : nil
	}
	
	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		
		guard let view = view as? UITableViewHeaderFooterView else {
			return
		}
		
		view.backgroundView?.setTheme()
		
		let theme = Theme()
		view.backgroundView?.backgroundColor = theme.altBackgroundColor
		
		if theme.isNight {
			view.textLabel?.textColor = .white
		}
	}
	
	// MARK: UITableViewDelegate functions
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		// Trigger a search using the selected term
		searchController.isActive = true
		searchController.searchBar.text = recentSearches[indexPath.row]
	}
	
	// MARK: Private functions
	private func loadRecent() -> [String] {
		
		if let recent = NSKeyedUnarchiver.unarchiveObject(withFile: recentSearchesArchive) as? [String] {
			log("Previous search terms loaded from archive")
			return recent
		} else {
			log("Unable to load previous search terms, starting new")
			return [String]()
		}
	}
}

// MARK: UISearchControllerDelegate conformance
extension SearchViewController: UISearchControllerDelegate {
	
	func willDismissSearchController(_ searchController: UISearchController) {
		
		tableView.reloadData()
	}
}

// MARK: SearchTermDelegate conformance
extension SearchViewController: SearchTermDelegate {
	
	func didPerformSearch(withTerm searchTerm: String) {
		
		lastSearchTerm = searchTerm
		
		if searchTerm.trimmingCharacters(in: .whitespaces).isEmpty {
			return
		}
		
		// Kick off a save in a few seconds for this search term for the recent list
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(2)) {
			
			// Cancel the save if we started another search by the time this ran
			if self.lastSearchTerm != searchTerm {
				
				log("Last search term \(self.lastSearchTerm ?? "nil") doesn't match pending save \(searchTerm)")
				return
			}
			
			// We're only storing a few terms - don't bother with duplicates
			if self.recentSearches.contains(searchTerm) {
				return
			}
			
			if self.recentSearches.count == self.recentSearchTermLimit {
				self.recentSearches.removeLast()
			}
			
			self.recentSearches.insert(searchTerm, at: 0)
			log("Added recent search term \(searchTerm)")
		}
	}
}
