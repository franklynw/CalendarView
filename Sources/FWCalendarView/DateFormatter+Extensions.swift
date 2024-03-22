//
//  DateFormatter+Extensions.swift
//  
//
//  Created by Franklyn on 22/03/2024.
//

import Foundation


extension DateFormatter {
    
    static var eventDateKeyFormatter: DateFormatter {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "y-MM-dd"
        
        return formatter
    }
}
