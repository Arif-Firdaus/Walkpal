//
//  WalkpalPeripheral.swift
//  BreakfastFinder
//
//  Created by Arif Firdaus on 11/20/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

class WalkpalPeripheral: NSObject {

    public static let caneServiceUUID     = CBUUID.init(string: "FFE0")
    public static let customServiceUUID     = CBUUID.init(string: "FFE1")

}
