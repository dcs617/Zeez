import SwiftUI

struct WeeklyProgressView: View {
    let sessions: [SleepSession]
    @Binding var selectedDate: Date
    @State private var currentWeekStart: Date
    private let calendar = Calendar.current
    
    init(sessions: [SleepSession], selectedDate: Binding<Date>) {
        self.sessions = sessions
        self._selectedDate = selectedDate
        
        // Get the start of the week containing the selected date
        let startOfWeek = Calendar.current.date(from: 
            Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate.wrappedValue)
        ) ?? selectedDate.wrappedValue
        
        // Initialize the week start
        self._currentWeekStart = State(initialValue: startOfWeek)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(weekDates, id: \.self) { date in
                WeekDayArc(
                    date: date,
                    session: findSession(for: date),
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date)
                )
                .id(date)
                .onTapGesture {
                    withAnimation {
                        selectedDate = date
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .gesture(
            DragGesture()
                .onEnded { value in
                    handleSwipe(with: value)
                }
        )
        .onChange(of: selectedDate) { _, newDate in
            alignToWeek(containing: newDate)
        }
    }
    
    private var weekDates: [Date] {
        var dates: [Date] = []
        var currentDate = currentWeekStart
        
        for _ in 0..<7 {
            dates.append(currentDate)
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDate
            }
        }
        
        return dates
    }
    
    private func findSession(for date: Date) -> SleepSession? {
        sessions.first { session in
            guard let startTime = session.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: date)
        }
    }
    
    private func handleSwipe(with value: DragGesture.Value) {
        let threshold: CGFloat = 50
        if value.translation.width > threshold {
            moveWeek(by: -1)
        } else if value.translation.width < -threshold {
            moveWeek(by: 1)
        }
    }
    
    private func moveWeek(by numberOfWeeks: Int) {
        withAnimation {
            if let newStart = calendar.date(byAdding: .weekOfYear,
                                         value: numberOfWeeks,
                                         to: currentWeekStart) {
                currentWeekStart = newStart
                // Also update selected date to the same day in the new week
                if let newSelectedDate = calendar.date(byAdding: .weekOfYear,
                                                     value: numberOfWeeks,
                                                     to: selectedDate) {
                    selectedDate = newSelectedDate
                }
            }
        }
    }
    
    private func alignToWeek(containing date: Date) {
        if let weekStart = calendar.date(from: 
            calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) {
            if !calendar.isDate(weekStart, 
                              equalTo: currentWeekStart, 
                              toGranularity: .weekOfYear) {
                withAnimation {
                    currentWeekStart = weekStart
                }
            }
        }
    }
}

struct WeekDayArc: View {
    let date: Date
    let session: SleepSession?
    let isSelected: Bool
    let isToday: Bool
    private let calendar = Calendar.current
    
    private var sleepDuration: Double {
        guard let session = session,
              let startTime = session.startTime,
              let endTime = session.endTime else {
            return 0
        }
        return endTime.timeIntervalSince(startTime) / 3600
    }
    
    private var shouldShowX: Bool {
        let isPastDate = date < calendar.startOfDay(for: Date())
        return isPastDate && sleepDuration == 0
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 40, height: 40)
                
                if date <= Date() {
                    if sleepDuration > 0 {
                        Circle()
                            .trim(from: 0, to: CGFloat(min(sleepDuration / 12, 1)))
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                    } else if shouldShowX {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(.red.opacity(0.5))
                    }
                }
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .gray)
            }
            
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2)
                .foregroundColor(isSelected ? .primary : .gray)
        }
        .frame(width: 44)
        .opacity(date > Date() ? 0.5 : 1)
    }
}
