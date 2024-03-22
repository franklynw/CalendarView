//
//  Date+Extensions.swift
//  
//
//  Created by Franklyn on 22/03/2024.
//

import Foundation


extension Date {
    
    func toNearestNextHour() -> Date {
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        
        let hour: Int
        if components.minute == 0 {
            hour = components.hour!
        } else {
            hour = components.hour! + 1
        }
        
        let allComponents = DateComponents(calendar: calendar, year: components.year, month: components.month, day: components.day, hour: hour)
        
        return calendar.date(from: allComponents)!
    }
    
    func startOfDay() -> Date {
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        
        return calendar.date(from: components)!
    }
    
    func endOfDay() -> Date {
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.date(from: components)!)!
    }
    
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
