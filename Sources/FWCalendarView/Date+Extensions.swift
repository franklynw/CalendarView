//
//  Date+Extensions.swift
//  
//
//  Created by Franklyn on 22/03/2024.
//

import Foundation


extension Date {
    
    func startOfMonth() -> Date {
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        
        return calendar.date(from: components)!
    }
    
    func startOfPreviousMonth() -> Date {
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        
        return calendar.date(byAdding: DateComponents(month: -1), to: calendar.date(from: components)!)!
    }
    
    func startOfNextMonth() -> Date {
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        
        return calendar.date(byAdding: DateComponents(month: 1), to: calendar.date(from: components)!)!
    }
    
    func endOfMonth() -> Date {
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        
        return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(from: components)!)!
    }
    
    func endOfPreviousMonth() -> Date {
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        
        return calendar.date(byAdding: DateComponents(day: -1), to: calendar.date(from: components)!)!
    }
}
