//
//  Item.swift
//  TravelJournal
//
//  Created by Gary Crook on 13/06/2026.
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
