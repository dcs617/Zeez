import Foundation

enum DateHelper {
    static func calculateSleepDuration(startTime: Date, endTime: Date) -> TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    static func calculateSleepHours(startTime: Date, endTime: Date) -> Double {
        return calculateSleepDuration(startTime: startTime, endTime: endTime) / 3600
    }
    
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }
    
    static func startOfDay(for date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
    
    static func daysAgo(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
    
    // Add this function to DateHelper.swift
    static func hoursBetween(start: Date, end: Date) -> Double {
        return end.timeIntervalSince(start) / 3600
    }
}
