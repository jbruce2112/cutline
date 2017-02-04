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
	}
}

extension CaptionView: UITextViewDelegate {
	
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
