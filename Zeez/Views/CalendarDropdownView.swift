import SwiftUI
import os.log

struct CalendarDropdownView: View {
    @Binding var selectedDate: Date
    @Binding var isShowing: Bool
    let sessions: [SleepSession]
    var onDateSelected: (Date) -> Void
    
    @State private var currentMonth: Date
    private let calendar = Calendar.current
    private let daysInWeek = 7
    
    init(selectedDate: Binding<Date>, isShowing: Binding<Bool>, sessions: [SleepSession], onDateSelected: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self._isShowing = isShowing
        self.sessions = sessions
        self.onDateSelected = onDateSelected
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Previous month")
                .accessibilityHint("Navigate to previous month in calendar")
                .accessibilityIdentifier("previousMonthButton")
                
                Spacer()
                
                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 18, weight: .semibold))
                    .accessibilityLabel("Current month: \(currentMonth.formatted(.dateTime.month(.wide).year()))")
                    .accessibilityIdentifier("currentMonthLabel")
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .disabled(calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? Date() > Date())
                .opacity(calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? Date() > Date() ? 0.3 : 1)
                .accessibilityLabel("Next month")
                .accessibilityHint("Navigate to next month in calendar")
                .accessibilityIdentifier("nextMonthButton")
            }
            .padding(.horizontal, 8)
            
            // Day headers
            HStack(spacing: 0) {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Weekday headers")
            .accessibilityHidden(true)
            .padding(.horizontal, 4)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: daysInWeek), spacing: 12) {
                ForEach(days, id: \.date) { day in
                    if let date = day.date {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedDate = date
                                onDateSelected(date)
                                isShowing = false
                            }
                        }) {
                            CalendarDayView(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date),
                                isCurrentMonth: day.isCurrentMonth,
                                hasSleepData: hasSleepData(for: date),
                                sleepQuality: getSleepQuality(for: date),
                                isFutureDate: date > Date()
                            )
                        }
                        .disabled(date > Date())
                        .accessibilityLabel(dateAccessibilityLabel(for: date, hasSleepData: hasSleepData(for: date), quality: getSleepQuality(for: date)))
                        .accessibilityHint(date > Date() ? "Future date, cannot select" : "Select this date to view sleep data")
                        .accessibilityIdentifier("calendarDay_\(calendar.component(.day, from: date))")
                    } else {
                        Color.clear
                            .frame(height: 36)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .frame(width: 320)
    }
    
    private var days: [(date: Date?, isCurrentMonth: Bool)] {
        let calendar = Calendar.current
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }
        
        let dateInterval = DateInterval(start: monthFirstWeek.start, end: monthLastWeek.end)
        var dates: [(Date?, Bool)] = []
        
        calendar.enumerateDates(
            startingAfter: dateInterval.start - 1,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) { date, _, stop in
            if let date = date {
                if date > dateInterval.end {
                    stop = true
                } else {
                    let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                    dates.append((date, isCurrentMonth))
                }
            }
        }
        
        return dates
    }
    
    private func hasSleepData(for date: Date) -> Bool {
        sessions.contains { session in
            guard let startTime = session.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: date)
        }
    }
    
    private func getSleepQuality(for date: Date) -> Double? {
        if let session = sessions.first(where: { session in
            guard let startTime = session.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: date)
        }) {
            return session.qualityScore
        }
        return nil
    }
    
    private func previousMonth() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        let nextDate = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        if nextDate <= Date() {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentMonth = nextDate
            }
        }
    }
    
    private func dateAccessibilityLabel(for date: Date, hasSleepData: Bool, quality: Double?) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMMM d"
        let dateString = dayFormatter.string(from: date)
        
        var label = dateString
        
        if calendar.isDateInToday(date) {
            label += ", today"
        }
        
        if calendar.isDate(date, inSameDayAs: selectedDate) {
            label += ", selected"
        }
        
        if hasSleepData {
            if let quality = quality {
                let qualityDescription = qualityDescription(for: quality)
                label += ", has sleep data with \(qualityDescription) quality"
            } else {
                label += ", has sleep data"
            }
        } else if date < Date() {
            label += ", no sleep data"
        }
        
        return label
    }
    
    private func qualityDescription(for quality: Double) -> String {
        switch quality {
        case 0..<50: return "poor"
        case 50..<70: return "fair"
        case 70..<85: return "good"
        default: return "excellent"
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let hasSleepData: Bool
    let sleepQuality: Double?
    let isFutureDate: Bool
    
    private var qualityColor: Color {
        guard let quality = sleepQuality else { return .gray }
        switch quality {
        case 0..<50: return .red
        case 50..<70: return .orange
        case 70..<85: return .yellow
        default: return .green
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected ? Color.blue :
                    isToday ? Color.blue.opacity(0.15) :
                    Color.clear
                )
                .frame(width: 36, height: 36)
            
            // Quality indicator
            if hasSleepData && !isSelected {
                Circle()
                    .fill(qualityColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Circle()
                    .stroke(qualityColor, lineWidth: 2)
                    .frame(width: 32, height: 32)
            }
            
            // Content
            if !hasSleepData && !isFutureDate && isCurrentMonth && date < Date() {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red.opacity(0.6))
            }
            
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 16, weight: isSelected || isToday ? .semibold : .regular))
                .foregroundColor(
                    isSelected ? .white :
                    isToday ? .blue :
                    isCurrentMonth ? (isFutureDate ? .gray.opacity(0.4) : .primary) : .gray.opacity(0.3)
                )
        }
        .frame(width: 36, height: 36)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

#Preview {
    VStack {
        CalendarDropdownView(
            selectedDate: .constant(Date()),
            isShowing: .constant(true),
            sessions: []
        ) { _ in }
    }
    .padding()
    .background(Color(UIColor.secondarySystemBackground))
}
