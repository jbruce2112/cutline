//
//  WebViewController.swift
//  Cutline
//
//  Created by John on 3/20/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class WebViewController: UIViewController {
	
	var url: URL!
	@IBOutlet var webView: UIWebView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let request = URLRequest(url: url)
		webView.loadRequest(request)
	}
	
	@IBAction func done() {
		dismiss(animated: true, completion: nil)
	}
}
