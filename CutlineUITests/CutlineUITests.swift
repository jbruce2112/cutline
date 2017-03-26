//
//  CutlineUITests.swift
//  CutlineUITests
//
//  Created by John on 3/26/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import XCTest

//swiftlint:disable line_length
class CutlineUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
		
		let app = XCUIApplication()
		app.launchArguments = ["UI_TEST_MODE"]
		app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation
		// - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
    func testExample() {
		
		let app = XCUIApplication()
		app.navigationBars["Cutline"].buttons["Add"].tap()
		app.tables.buttons["Camera Roll"].tap()
		app.collectionViews["PhotosGridView"].cells["Photo, Landscape, March 12, 2011, 7:17 PM"].tap()
		
		let textView = app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .textView).element
		textView.tap()
		
		// Create the caption
		let uniqueCaption = UUID().uuidString
		textView.typeText(uniqueCaption)
		app.navigationBars["Create"].buttons["Cutline"].tap()
		
		// Revisit the caption and ensure it has the same text
		app.collectionViews.children(matching: .cell).element(boundBy: 1).otherElements.children(matching: .image).element.tap()
		let caption = textView.value as! String
		XCTAssertEqual(caption, uniqueCaption)
		
		// Search for it
		app.tabBars.buttons["Search"].tap()
		app.searchFields["Search"].typeText(caption)
		app.tables["Search results"].children(matching: .cell).element(boundBy: 0).staticTexts[caption].tap()
		app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .textView).element.tap()
    }
    
}
