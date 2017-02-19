//
//  CaptionView.swift
//  Cutlines
//
//  Created by John Bruce on 2/4/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

class CaptionView: UITextView {
	
	override var text: String! {
		
		didSet {
			if text == placeholderText {
				textColor = .lightGray
			} else {
				textColor = .black
			}
		}
	}
	
	let placeholderText = "Your notes here"
	
	override init(frame: CGRect, textContainer: NSTextContainer?) {
		super.init(frame: frame, textContainer: textContainer)
		
		setup()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	//TODO: why do we have to do this too?
	override func awakeFromNib() {
		super.awakeFromNib()
		
		setup()
	}
	
	private func setup() {
		
		text = placeholderText
		font = UIFont.preferredFont(forTextStyle: .body)
		textContainerInset = UIEdgeInsets(top: 16, left: 8, bottom: 16, right: 8)
		
		delegate = self
		
		// Register observers for on-screen keyboard display events
		let notificationCenter = NotificationCenter.default
		notificationCenter.addObserver(self, selector: #selector(keyboardDidShow),
		                               name: NSNotification.Name.UIKeyboardDidShow, object: nil)
		notificationCenter.addObserver(self, selector: #selector(keyboardWillHide),
		                               name: NSNotification.Name.UIKeyboardWillHide, object: nil)
	}
	
	// MARK: keyboard display handlers
	func keyboardDidShow(_ notification: NSNotification) {
		
		// Move up the our scroll and content insets
		// so the cursor doesn't run underneath the on-screen keyboard
		let keyboardFrame = notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
		let keyboardSize = keyboardFrame.cgRectValue.size
		
		// TODO: this doesn't look quite right on the SE
		let contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0)
		contentInset = contentInsets
		scrollIndicatorInsets = contentInsets
	}
	
	func keyboardWillHide(_ notification: NSNotification) {
		
		// Reset the our insets
		let contentInsets = UIEdgeInsets.zero
		contentInset = contentInsets
		scrollIndicatorInsets = contentInsets
	}
}

extension CaptionView: UITextViewDelegate {
	
	// TODO: There should be a better way of doing this
	// that doensn't need to mess with the text property
	func textViewDidBeginEditing(_ textView: UITextView) {
		
		if textView.text == placeholderText {
			textView.text = ""
		}
		
		textView.becomeFirstResponder()
	}
	
	func textViewDidEndEditing(_ textView: UITextView) {
		
		if textView.text.isEmpty {
			textView.text = placeholderText
		}
		
		textView.resignFirstResponder()
	}
}
