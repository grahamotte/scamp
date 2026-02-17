//
//  Item.swift
//  Scamp
//
//  Created by Graham Otte on 2/16/26.
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
