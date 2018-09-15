//
//  CreateViewController.swift
//  Cutlines
//
//  Created by John on 1/31/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit
import Photos

class CreateViewController: UIViewController {

	// MARK: Properties
	var image: UIImage!
	var fileURL: URL?
	var photoManager: PhotoManager!
	
	private var containerView = PhotoContainerView()
	private var canceled = false
	
	// MARK: Functions
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.addSubview(containerView)
		
		containerView.polaroidView.image = image
		
		let flipButton = UIBarButtonItem(image: #imageLiteral(resourceName: "refresh"), style: .plain, target: containerView, action: #selector(PhotoContainerView.flip))
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		
		navigationItem.setRightBarButtonItems([cancelButton, flipButton], animated: false)
		
		navigationItem.title = "Add"
		
		// Grow the containerView as large as the top and bottom layout guides permit
		
		// containter.top = topLayoutGuide.bottom + 10
		let topEQ = containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
		
		// bottomLayoutGuide.top = container.bottom + 10
		let bottomEQ = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 10)
		
		topEQ.priority = UILayoutPriority.defaultHigh
		bottomEQ.priority = UILayoutPriority.defaultHigh
		
		topEQ.isActive = true
		bottomEQ.isActive = true
		
		// container.top >= topLayoutGuide.bottom + 10
		containerView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
		
		// bottomLayoutGuide.top >= container.bottom + 10
		view.safeAreaLayoutGuide.bottomAnchor.constraint(greaterThanOrEqualTo: containerView.bottomAnchor, constant: 10).isActive = true
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setTheme()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		if !canceled {
			save()
		}
	}
	
	@objc func cancel() {
		
		canceled = true
		navigationController?.popViewController(animated: true)
	}
	
	// MARK: Actions
	@IBAction func backgroundTapped(_ sender: UITapGestureRecognizer) {
		
		containerView.captionView.endEditing(true)
	}
	
	private func save() {
		
		guard let creationDate = getCreationDate() else {
			return
		}
		
		photoManager.add(image: image, caption: containerView.captionView.getCaption(), dateTaken: creationDate, completion: nil)
	}
	
	private func getCreationDate() -> Date? {
		
		// If we have the fileURL, try and read the ctime from that
		if
			let fileURL = fileURL,
			let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.relativePath),
			let ctime = attrs[.creationDate] as? Date {
			return ctime
		}
		
		return nil
	}
}
