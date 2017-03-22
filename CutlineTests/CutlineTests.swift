//
//  CutlineTests.swift
//  CutlineTests
//
//  Created by John on 3/11/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import XCTest
@testable import Cutline

class CutlineTests: XCTestCase {
	
	var photoManager: PhotoManager!
	
	var tempURL: URL!
	var photoStoreURL: URL!
	var imageStoreURL: URL!
	var thumbStoreURL: URL!
	
	override func setUp() {
		// Put setup code here. This method is called before the invocation of each test method in the class.
		super.setUp()
		
		tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("unit_test-\(UUID().uuidString)")
		try! FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
		
		photoStoreURL = tempURL.appendingPathComponent("PhotoStore_test.sqlite")
		imageStoreURL = tempURL.appendingPathComponent("images")
		thumbStoreURL = tempURL.appendingPathComponent("thumbs")
		
		photoManager = PhotoManager()
		photoManager.cloudManager = MocCloudKitManager()
		photoManager.photoStore = PhotoStore(storeURL: photoStoreURL)
		photoManager.imageStore = ImageStore(imageDirURL: imageStoreURL, thumbDirURL: thumbStoreURL)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
		
		photoManager = nil
		try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testPhotoAdd() {
		
		XCTAssertEqual(photoManager.photoStore.photos.count, 0)
		var count = photoManager.photoStore.fetchOnlyLocal(limit: nil).count
		XCTAssertEqual(count, 0)
		
		let square = image(withColor: .green, size: CGSize(width: 10, height: 10))
		addPhoto(image: square, caption: "My green square", expecting: .success)
		
		count = photoManager.photoStore.fetchModified(limit: nil).count
		XCTAssertEqual(count, 0)
		
		count = photoManager.photoStore.fetchDeleted(limit: nil).count
		XCTAssertEqual(count, 0)
		
		let photo = photoManager.photoStore.fetchOnlyLocal(limit: nil).first!
		let fetchedPhoto = photoManager.photoStore.fetch(withID: photo.id!)
		XCTAssertEqual(photo.id!, fetchedPhoto?.id)
		
		refreshPhotos(assertCount: 1)
    }
	
	func testPhotoSearch() {
		
		var count = photoManager.photoStore.fetchOnlyLocal(limit: nil).count
		XCTAssertEqual(count, 0)
		
		var square = image(withColor: .red, size: CGSize(width: 10, height: 10))
		addPhoto(image: square, caption: "My red square", expecting: .success)
		
		square = image(withColor: .blue, size: CGSize(width: 10, height: 10))
		addPhoto(image: square, caption: "My blue square", expecting: .success)
		
		count = photoManager.photoStore.fetchOnlyLocal(limit: nil).count
		XCTAssertEqual(count, 2)
		
		count = photoManager.photoStore.fetch(containing: "square").count
		XCTAssertEqual(count, 2)
		
		count = photoManager.photoStore.fetch(containing: "blahblah").count
		XCTAssertEqual(count, 0)
		
		count = photoManager.photoStore.fetch(containing: " RED ").count
		XCTAssertEqual(count, 1)
		
		refreshPhotos(assertCount: 2)
	}
	
	func testPhotoUpdate() {
		
		let square = image(withColor: .orange, size: CGSize(width: 10, height: 10))
		let caption = "My orange square"
		addPhoto(image: square, caption: caption, expecting: .success)
		
		let photo = photoManager.photoStore.fetchOnlyLocal(limit: nil).first!
		XCTAssertEqual(photo.caption!, caption)
		XCTAssertEqual(photo.dirty, false)
		refreshPhotos(assertCount: 1)
		
		photo.caption = "Update 1"
		updatePhoto(photo: photo, expecting: .success)
		XCTAssertEqual(photo.dirty, false)
		refreshPhotos(assertCount: 1)
		
		var modifiedPhotos = photoManager.photoStore.fetchModified(limit: nil)
		XCTAssertEqual(modifiedPhotos.count, 0)
		
		// Set the cloudManager to fail on the next call
		setCloudFailureMode(fail: true)
		let failResult = PhotoUpdateResult.failure(NSError(domain: "", code: 0, userInfo: nil))
		
		photo.caption = "Update 2"
		updatePhoto(photo: photo, expecting: failResult)
		XCTAssertEqual(photo.dirty, true)
		
		modifiedPhotos = photoManager.photoStore.fetchModified(limit: nil)
		XCTAssertEqual(modifiedPhotos.count, 1)
		XCTAssertEqual(modifiedPhotos.first!.caption!, "Update 2")
		refreshPhotos(assertCount: 1)
		
		setCloudFailureMode(fail: false)
		
		updatePhoto(photo: photo, expecting: .success)
		
		// Make sure it's no longer dirty
		XCTAssertEqual(photo.dirty, false)
		
		modifiedPhotos = photoManager.photoStore.fetchModified(limit: nil)
		XCTAssertEqual(modifiedPhotos.count, 0)
		refreshPhotos(assertCount: 1)
	}
	
	func testPhotoDelete() {
		
		let square = image(withColor: .yellow, size: CGSize(width: 10, height: 10))
		let caption = "My yellow square"
		addPhoto(image: square, caption: caption, expecting: .success)
		
		var photo = photoManager.photoStore.fetchOnlyLocal(limit: nil).first
		XCTAssertNotNil(photo)
		XCTAssertEqual(photo?.caption!, caption)
		XCTAssertEqual(photo?.markedDeleted, false)
		refreshPhotos(assertCount: 1)
		
		deletePhoto(photo: photo!, expecting: .success)
		
		var count = photoManager.photoStore.fetchDeleted(limit: nil).count
		XCTAssertEqual(count, 0)
		refreshPhotos(assertCount: 0)
		
		// Re-add the photo
		addPhoto(image: square, caption: caption, expecting: .success)
		
		// Grab it again
		photo = photoManager.photoStore.fetchOnlyLocal(limit: nil).first
		XCTAssertNotNil(photo)
		XCTAssertEqual(photo!.caption!, caption)
		XCTAssertEqual(photo!.markedDeleted, false)
		refreshPhotos(assertCount: 1)
		
		// fail the next cloud call
		setCloudFailureMode(fail: true)
		let failResult = PhotoUpdateResult.failure(NSError(domain: "", code: 0, userInfo: nil))
		
		deletePhoto(photo: photo!, expecting: failResult)
		
		XCTAssertEqual(photo!.markedDeleted, true)
		
		// Make sure we still have it
		photo = photoManager.photoStore.fetchDeleted(limit: nil).first
		XCTAssertNotNil(photo)
		XCTAssertEqual(photo!.caption!, caption)
		
		// It should be filtered out from our view when refreshing
		refreshPhotos(assertCount: 0)
		
		setCloudFailureMode(fail: false)
		
		deletePhoto(photo: photo!, expecting: .success)
		
		// Make sure its gone now
		count = photoManager.photoStore.fetchDeleted(limit: nil).count
		XCTAssertEqual(count, 0)
		count = photoManager.photoStore.fetchOnlyLocal(limit: nil).count
		XCTAssertEqual(count, 0)
		refreshPhotos(assertCount: 0)
	}
	
	func testDuplicateAdd() {
		
		let square = image(withColor: .red, size: CGSize(width: 10, height: 10))
		addPhoto(image: square, caption: "My red square", expecting: .success)
		
		let photo = photoManager.photoStore.fetchOnlyLocal(limit: nil).first!
		
		let addExpectation = expectation(description: "PhotoAdd")
		
		var failed = false
		photoManager.photoStore.add(id: photo.id!, caption: "Duplicate photo", dateTaken: Date()) { result in
			
			switch result {
			case .failure:
				failed = true
			default:
				break
			}
			addExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2) { error in
			
			XCTAssertNil(error)
			XCTAssertTrue(failed)
		}
	}
	
	private func addPhoto(image: UIImage, caption: String, expecting expectedResult: PhotoUpdateResult) {
		
		var updateResult: PhotoUpdateResult!
		let addExpectation = expectation(description: "PhotoAdd")
		
		photoManager.add(image: image, caption: caption, dateTaken: Date(), qos: nil) { result in
			
			updateResult = result
			addExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2) { error in
			
			XCTAssertNil(error)
			XCTAssertEqual(String(describing: updateResult!), String(describing: expectedResult))
		}
	}
	
	private func updatePhoto(photo: Photo, expecting expectedResult: PhotoUpdateResult) {
		
		var updateResult: PhotoUpdateResult!
		let addExpectation = expectation(description: "PhotoUpdate")
		
		photoManager.update(photo: photo) { result in
			
			updateResult = result
			addExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2) { error in
			
			XCTAssertNil(error)
			XCTAssertEqual(String(describing: updateResult!), String(describing: expectedResult))
		}
	}
	
	private func deletePhoto(photo: Photo, expecting expectedResult: PhotoUpdateResult) {
		
		var updateResult: PhotoUpdateResult!
		let addExpectation = expectation(description: "PhotoDelete")
		
		photoManager.delete(photo: photo) { result in
			
			updateResult = result
			addExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2) { error in
			
			XCTAssertNil(error)
			XCTAssertEqual(String(describing: updateResult!), String(describing: expectedResult))
		}
	}
	
	private func refreshPhotos(assertCount count: Int) {
		
		var refreshCount = 0
		let addExpectation = expectation(description: "PhotoRefresh")
		
		photoManager.photoStore.refresh { result in
			
			switch result {
			case .success:
				refreshCount = self.photoManager.photoStore.photos.count
			case .failure:
				refreshCount = 0
			}
			
			addExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2) { error in
			
			XCTAssertNil(error)
			XCTAssertEqual(count, refreshCount)
		}
	}
	
	private func image(withColor color: UIColor, size: CGSize) -> UIImage {
		
		let rect = CGRect(origin: CGPoint.zero, size: size)
		UIGraphicsBeginImageContextWithOptions(size, false, 0)
		color.setFill()
		UIRectFill(rect)
		
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return image!
	}
	
	private func setCloudFailureMode(fail: Bool) {
		(photoManager.cloudManager as! MocCloudKitManager).failureMode = fail
	}
	
}
