import XCTest

class CutlinesUITests: XCTestCase {
	
	func testCreateGridScreenshot() {
		let app = XCUIApplication()
		setupSnapshot(app)
		app.launch()
		snapshot("1_GridScreen")
	}
	
	func testCreateShareScreenshot() {
		let app = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
		setupSnapshot(app)
		app.launch()
		
		let milesWatchingBirdVideoPhoto = app.cells.element(boundBy: 7)
		milesWatchingBirdVideoPhoto.tap()
		
		app.buttons["Share"].tap()
		
		let shareExtensionButton = app.buttons["Add Caption"]
		if !shareExtensionButton.waitForExistence(timeout: 5.0) {
			let moreButton = app.buttons["More"]
			moreButton.tap()
			
			let shareExtensionSwitch = app.switches["Add Caption"]
			_ = shareExtensionSwitch.waitForExistence(timeout: 5.0)
			
			if shareExtensionSwitch.value as? String != "1" {
				shareExtensionSwitch.tap()
				print("tapped")
			}
			
			let doneButton = app.buttons["Done"]
			_ = doneButton.waitForExistence(timeout: 5.0)
			doneButton.tap()
		}
		
		_ = shareExtensionButton.waitForExistence(timeout: 5.0)
		shareExtensionButton.tap()
		
		let postModal = app.buttons["Post"]
		_ = postModal.waitForExistence(timeout: 5.0)
		
		snapshot("2_ShareExtensionScreen")
	}
	
	func testCreateCaptionSearchScreenshot() {
		
		let app = XCUIApplication()
		setupSnapshot(app)
		app.launch()
		
		app.tabBars.buttons["Search"].tap()
		let searchField = app.searchFields["Search"]
		searchField.tap()
		
		searchField.typeText("mackinac")
		
		snapshot("3_CaptionSearchScreen")
	}
	
	func testCreateShareMemoriesScreenshot() {
		
		let app = XCUIApplication()
		setupSnapshot(app)
		app.launch()
		
		let mackinacSunsetPhoto = app.collectionViews.cells.element(boundBy: 17)
		mackinacSunsetPhoto.tap()
		app.navigationBars["Edit"].buttons["refresh"].tap()
		
		let editHeader = app.staticTexts["Edit"]
		_ = editHeader.waitForExistence(timeout: 5.0)
		
		snapshot("4_ShareMemories")
	}
}
