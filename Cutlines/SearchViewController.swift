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
	var photoManager: PhotoManager!
	
	private var searchBar: UISearchBar!
	private var resultsViewController = SearchResultsViewController()
	
	fileprivate var recentSearches = [String]()
	
	fileprivate let recentSearchTermLimit = 5
	fileprivate var lastSearchTerm: String?
	fileprivate var recentSearchesArchive: String!
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		definesPresentationContext = true
		
		resultsViewController.photoManager = photoManager
		searchBar = resultsViewController.searchController.searchBar
		tableView.tableHeaderView = searchBar
		
		tableView.dataSource = self
		
		resultsViewController.searchController.delegate = self
		resultsViewController.searchTermDelegate = self
		
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		recentSearchesArchive = cacheDir.appendingPathComponent("recentSearches.archive").path		
		recentSearches = loadRecent()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		searchBar.becomeFirstResponder()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		saveRecent()
	}
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		searchBar.barStyle = theme.barStyle
		
		// force the section headers to refresh
		tableView.reloadSections(IndexSet(integer: 0), with: .none)
		
		tableView.backgroundView = UIView()
		tableView.backgroundView?.setTheme()
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
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		
		if section != 0 {
			return nil
		}
		
		let view = UITableViewHeaderFooterView()
		view.contentView.setTheme()
		
		let theme = view.contentView.theme()
		view.contentView.backgroundColor = theme.altBackgroundColor
		
		if theme.isNight {
			view.textLabel?.textColor = .white
		}
		
		return view
	}
	
	// MARK: UITableViewDelegate functions
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		// Trigger a search using the selected term
		resultsViewController.searchController.isActive = true
		resultsViewController.searchController.searchBar.text = recentSearches[indexPath.row]
	}
	
	// MARK: Private functions
	private func loadRecent() -> [String] {
		
		if let recent = NSKeyedUnarchiver.unarchiveObject(withFile: recentSearchesArchive) as? [String] {
			Log("Previous search terms loaded from archive")
			return recent
		} else {
			Log("Unable to load previous search terms, starting new")
			return [String]()
		}
	}
	
	private func saveRecent() {
		
		NSKeyedArchiver.archiveRootObject(recentSearches, toFile: recentSearchesArchive)
		Log("Recent searches saved")
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
		
		if searchTerm.isEmpty {
			return
		}
		
		// Kick off a save in a few seconds for this search term for the recent list
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(2)) {
			
			// Cancel the save if we started another search by the time this ran
			if self.lastSearchTerm != searchTerm {
				
				Log("Last search term \(self.lastSearchTerm) doesn't match pending save \(searchTerm)")
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
			Log("Added recent search term \(searchTerm)")
		}
	}
}
