//
//  Item.swift
//  Sift
//
//  Created by Don Noel on 10/19/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
