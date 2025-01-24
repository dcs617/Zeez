import SwiftUI

struct CalendarDropdownView: View {
    @Binding var selectedDate: Date
    @Binding var isShowing: Bool
    let sessions: [SleepSession]  // Added to check for sleep data
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
        VStack(alignment: .leading, spacing: 12) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(currentMonth.formatted(.dateTime.month().year()))
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 8)
            
            // Day headers
            HStack {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.gray)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: daysInWeek), spacing: 8) {
                ForEach(days, id: \.date) { day in
                    if let date = day.date {
                        Button(action: {
                            selectedDate = date
                            onDateSelected(date)
                            isShowing = false
                        }) {
                            CalendarDayView(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isCurrentMonth: day.isCurrentMonth,
                                hasSleepData: hasSleepData(for: date),
                                isFutureDate: date > Date()
                            )
                        }
                        .disabled(date > Date())
                    } else {
                        Text("")
                            .frame(height: 32)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(width: 300)
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
    
    private func previousMonth() {
        withAnimation {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        let nextDate = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        if nextDate <= Date() {
            withAnimation {
                currentMonth = nextDate
            }
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let hasSleepData: Bool
    let isFutureDate: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
                .frame(width: 32, height: 32)
            
            if !hasSleepData && !isFutureDate && isCurrentMonth {
                Image(systemName: "xmark")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.5))
            }
            
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 16))
                .foregroundColor(
                    isSelected ? .white :
                        isCurrentMonth ? (isFutureDate ? .gray.opacity(0.5) : .primary) : .gray.opacity(0.3)
                )
        }
        .frame(height: 32)
    }
}
