//
//  SyncState.swift
//  Cutlines
//
//  Created by John on 3/14/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import CloudKit
import Foundation

/// SyncState is a thread safe object that holds all client sync state.
class SyncState: NSObject, NSCoding {
	
	// MARK: private properties (persisted)
	private var _dbChangeToken: CKServerChangeToken?
	private var _zoneChangeToken: CKServerChangeToken?
	private var _recordZone: CKRecordZone?
	private var _subscribedForChanges = false
	
	/// Queue that ensures thread safety - internal to this class
	private let queue = DispatchQueue(label: "cutlines.syncStateQueue")
	
	override init() {
		super.init()
	}
	
	required init?(coder aDecoder: NSCoder) {
		
		_subscribedForChanges = aDecoder.decodeBool(forKey: "subscribedForChanges")
		_zoneChangeToken = aDecoder.decodeObject(forKey: "zoneChangeToken") as? CKServerChangeToken
		_dbChangeToken = aDecoder.decodeObject(forKey: "dbChangeToken") as? CKServerChangeToken
		_recordZone = aDecoder.decodeObject(forKey: "recordZone") as? CKRecordZone
	}
	
	func encode(with aCoder: NSCoder) {
		
		queue.sync {
			aCoder.encode(_recordZone, forKey: "recordZone")
			aCoder.encode(_dbChangeToken, forKey: "dbChangeToken")
			aCoder.encode(_zoneChangeToken, forKey: "zoneChangeToken")
			aCoder.encode(_subscribedForChanges, forKey: "subscribedForChanges")
		}
	}
	
	/// Resets internal state and causes
	/// all events to be re-fetched from the cloud
	/// on the next call to fetchChanges()
	func reset() {
		
		queue.sync {
			_dbChangeToken = nil
			_zoneChangeToken = nil
			_recordZone = nil
			_subscribedForChanges = false
		}
	}
	
	/// Marker that represents the last time we got changes from the database
	var dbChangeToken: CKServerChangeToken? {
		get {
			return queue.sync { _dbChangeToken }
		}
		set {
			queue.sync { _dbChangeToken = newValue }
		}
	}
	
	/// Marker that represents the last object that we synced for our zone
	var zoneChangeToken: CKServerChangeToken? {
		get {
			return queue.sync { _zoneChangeToken }
		}
		set {
			queue.sync { _zoneChangeToken = newValue }
		}
	}
	
	/// The record that represents the zone for all user objects
	var recordZone: CKRecordZone? {
		get {
			return queue.sync { _recordZone }
		}
		set {
			queue.sync { _recordZone = newValue }
		}
	}
	
	/// A bool that represents if this client has
	/// registered for push events for this database
	var subscribedForChanges: Bool {
		get {
			return queue.sync { _subscribedForChanges }
		}
		set {
			queue.sync { _subscribedForChanges = newValue }
		}
	}
}
