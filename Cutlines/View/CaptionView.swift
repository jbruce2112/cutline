//
//  CaptionView.swift
//  Cutlines
//
//  Created by John on 2/4/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import UIKit

/// CaptionView is a specialization of UITextView
/// that takes care of updating the various insets
/// when the keyboard changes and screen rotates.
/// It also manages the placeholder text for the view.
class CaptionView: UITextView {
	
	override var text: String! {
		
		didSet {
			if text == captionPlaceholder {
				textColor = .lightGray
			} else {
				textColor = .black
			}
		}
	}
	
	override init(frame: CGRect, textContainer: NSTextContainer?) {
		super.init(frame: frame, textContainer: textContainer)
		
		setup()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	/// Called on object after its loaded from archive (storyboard or nib)
	override func awakeFromNib() {
		super.awakeFromNib()
		
		setup()
	}
	
	override func setTheme(_ theme: Theme) {
		// Don't set standard theme properties with super call
		
		keyboardAppearance = theme.keyboard
	}
	
	// MARK: keyboard display handlers
	
	func resizeInsetsForKeyboard(_ notification: NSNotification) {
		
		let kbValue = notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
		let keyboard = kbValue.cgRectValue
		
		// Calculate how much the keyboard is overlapping with
		// this view & move up the our scroll and content insets
		// so the cursor doesn't run underneath the on-screen keyboard
		let winCoords = convert(bounds, to: nil)
		let bottomY = winCoords.origin.y + winCoords.size.height
		
		let overlap = bottomY - keyboard.origin.y
		if overlap < 0 {
			return
		}
		
		let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: overlap, right: 0.0)
		contentInset = contentInsets
		scrollIndicatorInsets = contentInsets
	}
	
	func keyboardWillHide(_ notification: NSNotification) {
		
		// Reset the our insets
		let contentInsets = UIEdgeInsets.zero
		contentInset = contentInsets
		scrollIndicatorInsets = contentInsets
	}
	
	func getCaption() -> String {
		
		if text == captionPlaceholder {
			return ""
		} else {
			return text
		}
	}
	
	// MARK: Private functions
	private func setup() {
		
		text = captionPlaceholder
		font = UIFont.preferredFont(forTextStyle: .body)
		textContainerInset = UIEdgeInsets(top: 16, left: 8, bottom: 16, right: 8)
		backgroundColor = .clear
		
		setTheme()
		
		delegate = self
		
		// Register observers for on-screen keyboard display events
		let notificationCenter = NotificationCenter.default
		notificationCenter.addObserver(self, selector: #selector(resizeInsetsForKeyboard),
		                               name: NSNotification.Name.UIKeyboardDidShow, object: nil)
		notificationCenter.addObserver(self, selector: #selector(keyboardWillHide),
		                               name: NSNotification.Name.UIKeyboardWillHide, object: nil)
		notificationCenter.addObserver(self, selector: #selector(resizeInsetsForKeyboard),
		                               name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
	}
}

// MARK: UITextViewDelegate
extension CaptionView: UITextViewDelegate {
	
	// TODO: There should be a better way of doing this
	// that doensn't need to mess with the text property
	// getCaption() can be removed once this is cleaned up
	func textViewDidBeginEditing(_ textView: UITextView) {
		
		if textView.text == captionPlaceholder {
			textView.text = ""
		}
	}
	
	func textViewDidEndEditing(_ textView: UITextView) {
		
		if textView.text.isEmpty {
			textView.text = captionPlaceholder
		}
		
		textView.resignFirstResponder()
	}
}
