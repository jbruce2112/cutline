//
//  main.swift
//  Cutlines
//
//  Created by John on 3/15/17.
//  Copyright © 2017 Bruce32. All rights reserved.
//

import Foundation
import UIKit

private var delegateClassName: String? {
	return NSClassFromString("XCTestCase") == nil ? NSStringFromClass(AppDelegate.self) : nil
}

_ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, delegateClassName)
