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
	private var searchResultsViewController = SearchResultsViewController()
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		definesPresentationContext = true
		
		searchResultsViewController.photoManager = photoManager
		searchBar = searchResultsViewController.searchController.searchBar
		tableView.tableHeaderView = searchBar
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func setTheme(_ theme: Theme) {
		super.setTheme(theme)
		
		searchBar.barStyle = theme.barStyle
	}
}
