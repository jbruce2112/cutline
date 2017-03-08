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
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		definesPresentationContext = true
		
		resultsViewController.photoManager = photoManager
		searchBar = resultsViewController.searchController.searchBar
		tableView.tableHeaderView = searchBar
		
		tableView.dataSource = self
		
		resultsViewController.searchController.delegate = self
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		resultsViewController.saveRecent()		
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
		
		return resultsViewController.recentSearches.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
		
		cell.textLabel!.text = resultsViewController.recentSearches[indexPath.row]
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
		resultsViewController.searchController.searchBar.text = resultsViewController.recentSearches[indexPath.row]
	}
}

extension SearchViewController: UISearchControllerDelegate {
	
	func willDismissSearchController(_ searchController: UISearchController) {
		
		tableView.reloadData()
	}
}
