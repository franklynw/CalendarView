//
//  FWCalendarManager.swift
//
//  Created by Franklyn on 22/03/2024.
//

import SwiftUI
import Combine
import EventKit


public class FWCalendarManager: ObservableObject {
    
    public struct Config {
        let calendar: Calendar? // defaults to .current if nil
        let dateRange: DateInterval? // if nil then open-ended
        let calendarsFilter: (EKCalendar) -> Bool
        
        public static let `default`: Config = .init()
        
        public init(calendar: Calendar? = nil, dateRange: DateInterval? = nil, calendarsFilter: ((EKCalendar) -> Bool)? = nil) {
            self.calendar = calendar
            self.dateRange = dateRange
            self.calendarsFilter = calendarsFilter ?? { _ in true }
        }
    }
    
    private enum PurgeDirection {
        // this is used to control purging of cached events, so eg, if we page left to earlier events,
        // it'll purge from the 'end' (ie, more recent events); if we page right to more recent events,
        // it'll purge from the beginning (ie, events further in the past)
        // the aim is to leave a buffer of a month's worth of events either side of the current view
        case start(Date)
        case end(Date)
    }
    
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    private var subscriptions = Set<AnyCancellable>()
    private let eventStore = EKEventStore()
    
    let config: Config
    
    private var currentCalendarVisibleStartDate = Date().startOfMonth()
    
    @Published var events: [String: Set<FWCalendarView.CalendarEvent>] = [:] // key is eventDateKeyFormatter string from date
    @Published var calendarDateComponents: FWCalendarView.CalendarDateComponents?
    
    @Published public var calendars: [EKCalendar] = []
    @Published public var selectedCalendar: EKCalendar?
    
    
    public init(config: Config = .default) {
        
        self.config = config
        
        calendars = eventStore.calendars(for: .event).filter(config.calendarsFilter)
        
        $calendarDateComponents
            .sink { [weak self] components in
                guard let components = components else {
                    return
                }
                self?.calendarDidChangeVisibleDateComponents(to: components.visibleDateComponents, from: components.previousDateComponents)
            }
            .store(in: &subscriptions)
    }
    
    public func selectCalendar(_ calendar: EKCalendar?) {
        
        selectedCalendar = calendar
        events.removeAll()
        
        fetchEvents(for: currentCalendarVisibleStartDate.startOfPreviousMonth(), period: .quarter)
    }
    
    public func selectCalendar(withIdentifier calendarIdentifier: String?) {
        let calendar = calendars.first { $0.calendarIdentifier == calendarIdentifier }
        selectCalendar(calendar)
    }
    
    private func calendarDidChangeVisibleDateComponents(to newDateComponents: DateComponents, from previousDateComponents: DateComponents) {
        
        let calendar = Calendar.current
        guard let newDate = calendar.date(from: newDateComponents), let previousDate = calendar.date(from: previousDateComponents) else {
            return
        }
        
        let operation = AsyncOperation { [weak self] _, finished in
            DispatchQueue.main.async {
                self?.currentCalendarVisibleStartDate = newDate.startOfMonth()
                finished()
            }
        }
        
        if newDate < previousDate {
            fetchEvents(for: newDate.startOfPreviousMonth(), purging: .end(previousDate.startOfNextMonth()))
        } else {
            fetchEvents(for: newDate.startOfNextMonth(), purging: .start(previousDate.endOfPreviousMonth()))
        }
        
        queue.addOperation(operation)
    }
    
    private func fetchEvents(for date: Date, period: TimeInterval = .month, purging purgeDirection: PurgeDirection? = nil) {
        
        // fetch a month's-worth of dates from the start of the month for the given date
        
        guard let selectedCalendar = selectedCalendar else {
            return
        }
        
        let operation = AsyncOperation { [weak self] _, finished in
            
            guard let self = self else {
                return
            }
            
            let startDate = date.startOfMonth()
            let endDate = startDate.addingTimeInterval(period)
            
            let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [selectedCalendar])
            let events = self.eventStore.events(matching: predicate) as [EKEvent]
            
            var updatedEvents = self.events
            
            events.forEach { event in
                guard let eventStartDate = event.startDate, let eventEndDate = event.endDate else {
                    return
                }
                stride(from: eventStartDate, to: eventEndDate, by: .day).forEach { eventDate in
                    let newEvent = FWCalendarView.CalendarEvent(eventIdentifier: event.eventIdentifier, title: event.title, date: eventDate)
                    let eventKey = newEvent.eventKey
                    if var events = updatedEvents[eventKey] {
                        events.insert(newEvent)
                        updatedEvents[eventKey] = events
                    } else {
                        updatedEvents[eventKey] = [newEvent]
                    }
                }
            }
            
            switch purgeDirection {
            case .none:
                break
            case .start(let date):
                let startDate = date.addingTimeInterval(.month * -2)
                stride(from: startDate, to: date, by: .day).forEach { eventDate in
                    let eventKey = FWCalendarView.CalendarEvent.eventKey(for: eventDate)
                    updatedEvents.removeValue(forKey: eventKey)
                }
            case .end(let date):
                let endDate = date.addingTimeInterval(.month * 2)
                stride(from: date, to: endDate, by: .day).forEach { eventDate in
                    let eventKey = FWCalendarView.CalendarEvent.eventKey(for: eventDate)
                    updatedEvents.removeValue(forKey: eventKey)
                }
            }
            
            DispatchQueue.main.async {
                self.events = updatedEvents
                finished()
            }
        }
        
        queue.addOperation(operation)
    }
}
