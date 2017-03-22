//
//  main.swift
//  Cutline
//
//  Created by John on 3/15/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import Foundation
import UIKit

private func delegateClassName() -> String? {
	return NSClassFromString("XCTestCase") == nil ? NSStringFromClass(AppDelegate.self) : nil
}

let argv = UnsafeMutableRawPointer(CommandLine.unsafeArgv)
				.bindMemory(to: UnsafeMutablePointer<Int8>.self, capacity: Int(CommandLine.argc))

UIApplicationMain(CommandLine.argc, argv, nil, delegateClassName())
