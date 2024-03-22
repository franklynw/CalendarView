//
//  FWCalendarView.swift
//
//  Created by Franklyn on 20/03/2024.
//

import SwiftUI
import Combine
import EventKit


public struct FWCalendarView: UIViewRepresentable {
    
    public struct CalendarEvent: Hashable, Identifiable {
        public let eventIdentifier: String
        public let eventStartDate: Date
        public let isAllDay: Bool
        public let title: String
        public let date: Date // not the same as the event startDate, but the date it's shown in the calendar view
        
        public var id: String {
            return DateFormatter.eventDateKeyFormatter.string(from: date) + "|" + eventIdentifier
        }
        
        var eventKey: String {
            DateFormatter.eventDateKeyFormatter.string(from: date)
        }
        
        static func eventKey(for date: Date) -> String {
            DateFormatter.eventDateKeyFormatter.string(from: date)
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    public struct SelectedDate {
        public let date: Date
        public let events: Set<CalendarEvent>
    }
    
    // for some unknown reason, if we use an instance of UICalendarView.Decoration for the default decoration, it doesn't work (& crashes) - wtf?
    public struct Decoration {
        let color: UIColor
        let size: UICalendarView.DecorationSize
        
        public init(color: UIColor, size: UICalendarView.DecorationSize) {
            self.color = color
            self.size = size
        }
    }
    
    struct CalendarDateComponents {
        let visibleDateComponents: DateComponents
        let previousDateComponents: DateComponents
    }
    
    @ObservedObject var calendarManager: FWCalendarManager
    
    private var defaultDecoration: Decoration?
    private var decorationsProvider: ((Date) -> UICalendarView.Decoration?)?
    private var selectedDate: ((SelectedDate) -> ())?
    
    
    public init(calendarManager: FWCalendarManager) {
        self.calendarManager = calendarManager
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: Context) -> some UICalendarView {
        
        let view = CalendarViewWrapper() // so we can implement deinit
        
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        context.coordinator.setCalendarView(view)
        
        return view
    }
    
    public func updateUIView(_ uiView: UIViewType, context: Context) {}
    
    
    public class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        
        private weak var calendarView: UICalendarView?
        
        private var parent: FWCalendarView
        private var eventsCancellable: AnyCancellable?
        
        private let calendar: Calendar
        private var previousDateComponents: DateComponents?
        private var events: [String: Set<CalendarEvent>] = [:]
        
        private var link: CADisplayLink?
        
        
        init(_ parent: FWCalendarView) {
            
            self.parent = parent
            calendar = parent.calendarManager.config.calendar
            
            super.init()
            
            eventsCancellable = parent.calendarManager.$events
                .sink { [weak self] events in
                    
                    guard let self = self, let calendarView = self.calendarView else {
                        return
                    }
                    
                    self.events = events

                    let currentDateComponents = calendarView.visibleDateComponents

                    let startDate = currentDateComponents.date!.startOfMonth()
                    let endDate = startDate.endOfMonth()

                    // we need to make a set first to remove duplicates which we can get due to daylight saving changes
                    let dateComponents = Set(stride(from: startDate, to: endDate, by: .day).map { self.calendar.dateComponents([.year, .month, .day], from: $0) })

                    calendarView.reloadDecorations(forDateComponents: Array(dateComponents), animated: true)
                }
            
            if #unavailable(iOS 16.2) {
                // because the UICalendarViewDelegate didChangeVisibleDateComponentsFrom function is only called 16.2 onwards
                let link = CADisplayLink(target: self, selector: #selector(checkVisibleDateComponents))
                link.add(to: .main, forMode: .common)
                self.link = link
            }
        }
        
        func invalidateDisplayLink() {
            link?.invalidate()
        }
        
        fileprivate func setCalendarView(_ calendarView: CalendarViewWrapper) {
            
            self.calendarView = calendarView
            
            calendarView.delegate = self
            calendarView.calendar = calendar
            
            let dateSelection = UICalendarSelectionSingleDate(delegate: self)
            calendarView.selectionBehavior = dateSelection
            
            if let dateRange = parent.calendarManager.config.dateRange {
                calendarView.availableDateRange = dateRange
            }
            
            // song & dance because dismantleUIView isn't called
            calendarView.killAction = { [weak self] in
                self?.invalidateDisplayLink()
            }
        }
        
        @MainActor public func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            
            let eventDate = calendar.date(from: dateComponents)!
            
            if let decoration = parent.decorationsProvider?(eventDate) {
                return decoration
            }
            
            let eventKey = DateFormatter.eventDateKeyFormatter.string(from: eventDate)
            let calendarEvents = events[eventKey] ?? []

            guard !calendarEvents.isEmpty else {
                return nil
            }
            
            return .default(color: parent.defaultDecoration?.color ?? .blue, size: parent.defaultDecoration?.size ?? .large)
        }
        
        public func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents) {
            parent.calendarManager.calendarDateComponents = .init(visibleDateComponents: calendarView.visibleDateComponents, previousDateComponents: previousDateComponents)
        }
        
        public func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents = dateComponents, let date = calendar.date(from: dateComponents) else {
                return
            }
            let events = self.events[CalendarEvent.eventKey(for: date)] ?? []
            parent.selectedDate?(.init(date: date, events: events))
        }
        
        public func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
            true
        }
        
        /*
         This is only used pre-iOS 16.2, as the UICalendarViewDelegate function calendarView(_ calendarView:didChangeVisibleDateComponentsFrom:) isn't called
         */
        @objc
        private func checkVisibleDateComponents() {
            if calendarView?.visibleDateComponents != previousDateComponents {
                if let visibleDateComponents = calendarView?.visibleDateComponents, let previousDateComponents = previousDateComponents {
                    parent.calendarManager.calendarDateComponents = .init(visibleDateComponents: visibleDateComponents, previousDateComponents: previousDateComponents)
                    if abs(calendar.date(from: previousDateComponents)!.timeIntervalSince(calendar.date(from: visibleDateComponents)!)) > .month {
                        // if the user has selected another month from the picker
                        parent.calendarManager.currentCalendarVisibleStartDate = calendar.date(from: visibleDateComponents)!.startOfMonth()
                        parent.calendarManager.refreshCurrentCalendar()
                    }
                }
                previousDateComponents = calendarView?.visibleDateComponents
            }
        }
    }
}


public extension FWCalendarView {
    
    func onSelectDate(_ selectedDate: @escaping (SelectedDate) -> ()) -> Self {
        var copy = self
        copy.selectedDate = selectedDate
        return copy
    }
    
    func defaultDecoration(_ defaultDecoration: Decoration) -> Self {
        var copy = self
        copy.defaultDecoration = defaultDecoration
        return copy
    }
    
    func decorationsProvider(_ decorationsProvider: @escaping (Date) -> UICalendarView.Decoration?) -> Self {
        var copy = self
        copy.decorationsProvider = decorationsProvider
        return copy
    }
}


fileprivate class CalendarViewWrapper: UICalendarView {
    
    var killAction: (() -> ())?
    
    deinit {
        killAction?()
    }
}
