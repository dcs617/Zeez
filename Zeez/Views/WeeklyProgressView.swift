import SwiftUI
import os.log

struct WeeklyProgressView: View {
    let sessions: [SleepSession]
    @Binding var selectedDate: Date
    @State private var currentWeekStart: Date
    @GestureState private var dragOffset: CGFloat = 0
    @State private var weekOffset: Int = 0
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
        HStack(spacing: 0) {
            ForEach(-1...1, id: \.self) { weekIndex in
                HStack(spacing: 8) {
                    ForEach(Array(getWeekDates(for: weekIndex).enumerated()), id: \.element) { dayIndex, date in
                        WeekDayArc(
                            date: date,
                            session: findSession(for: date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date)
                        )
                        .id(date)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedDate = date
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(dayAccessibilityLabel(date: date, session: findSession(for: date)))
                        .accessibilityHint("Tap to select this date")
                        .accessibilityAddTraits(calendar.isDate(date, inSameDayAs: selectedDate) ? .isSelected : [])
                        .accessibilityIdentifier("weekDay_\(weekIndex)_\(dayIndex)")
                    }
                }
                .frame(width: 380)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, alignment: .center)
        .offset(x: (CGFloat(weekOffset) * 380) + dragOffset)
        .frame(height: 110)
        .clipped()
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    let velocity = value.predictedEndLocation.x - value.location.x
                    guard abs(velocity) > 30 else { return }
                    if abs(value.translation.width) > threshold {
                        let direction = value.translation.width > 0 ? -1 : 1
                        moveWeek(by: direction)
                    }
                }
        )
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: weekOffset)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: dragOffset)
        .onChange(of: selectedDate) { _, newDate in
            alignToWeek(containing: newDate)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weekly sleep progress view")
        .accessibilityHint("Swipe left or right to navigate between weeks, tap dates to select")
        .accessibilityIdentifier("weeklyProgressView")
    }
    
    private func dayAccessibilityLabel(date: Date, session: SleepSession?) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMMM d"
        let dayString = dayFormatter.string(from: date)
        
        var components = [dayString]
        
        if calendar.isDateInToday(date) {
            components.append("today")
        }
        
        if let session = session {
            if let duration = session.derivedSleepMetrics.recordedSessionInterval.value {
                let hours = Int(duration / 3600)
                let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
                components.append("recorded session duration \(hours) hours \(minutes) minutes")
            } else {
                components.append("recorded session duration not available")
            }
            
            if session.hasDisplayableScore {
                components.append("experimental Zeez estimated sleep score \(Int(session.qualityScore))")
            } else {
                components.append("experimental Zeez estimate not available")
            }
        } else if date < calendar.startOfDay(for: Date()) {
            components.append("no sleep data")
        }
        
        return components.joined(separator: ", ")
    }
    
    func getWeekDates(for weekOffset: Int) -> [Date] {
        guard let startDate = calendar.date(byAdding: .weekOfYear,
                                         value: weekOffset,
                                         to: currentWeekStart) else {
            return []
        }
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day,
                         value: dayOffset,
                         to: startDate)
        }
    }
    
    func findSession(for date: Date) -> SleepSession? {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return sessions.first { session in
            guard let startTime = session.startTime else { return false }
            return startTime >= startOfDay && startTime < endOfDay
        }
    }
    
    func handleSwipe(with value: DragGesture.Value) {
        let threshold: CGFloat = 50
        if value.translation.width > threshold {
            moveWeek(by: -1)
        } else if value.translation.width < -threshold {
            moveWeek(by: 1)
        }
    }
    
    func moveWeek(by numberOfWeeks: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if let newStart = calendar.date(byAdding: .weekOfYear,
                                         value: numberOfWeeks,
                                         to: currentWeekStart) {
                currentWeekStart = newStart
                weekOffset = 0
                
                // Update selected date to the same day in the new week
                if let newSelectedDate = calendar.date(byAdding: .weekOfYear,
                                                     value: numberOfWeeks,
                                                     to: selectedDate) {
                    selectedDate = newSelectedDate
                }
            }
        }
    }
    
    func alignToWeek(containing date: Date) {
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
              let duration = session.derivedSleepMetrics.recordedSessionInterval.value else {
            return 0
        }

        return duration / 3600 // Convert seconds to hours
    }
    
    private var shouldShowX: Bool {
        let isPastDate = date < calendar.startOfDay(for: Date())
        return isPastDate && sleepDuration == 0
    }
    
    private var ringColor: Color {
        sleepDuration == 0 ? Color.gray.opacity(0.2) : .blue
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 5)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                
                // Progress ring
                if date <= Date() && sleepDuration > 0 {
                    Circle()
                        .trim(from: 0, to: CGFloat(min(sleepDuration / 12, 1)))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: sleepDuration)
                        .accessibilityHidden(true)
                }
                
                // Content
                if shouldShowX {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.6))
                        .accessibilityHidden(true)
                } else {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .accessibilityHidden(true)
                }
                
                // Today indicator
                if isToday {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .offset(y: -26)
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2)
                .foregroundColor(isSelected ? .primary : .secondary)
                .fontWeight(isSelected ? .medium : .regular)
                .accessibilityHidden(true)
        }
        .frame(width: 48)
        .opacity(date > Date() ? 0.4 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayArcAccessibilityLabel)
        .accessibilityValue(sleepDuration > 0 ? "\(String(format: "%.1f", sleepDuration)) hours recorded session duration" : "no recorded session data")
        .accessibilityIdentifier("weekDayArc_\(calendar.component(.day, from: date))")
    }
    
    private var dayArcAccessibilityLabel: String {
        let day = calendar.component(.day, from: date)
        let weekday = date.formatted(.dateTime.weekday(.wide))
        
        var components = ["\(weekday) \(day)"]
        
        if isToday {
            components.append("today")
        }
        
        if isSelected {
            components.append("selected")
        }
        
        return components.joined(separator: ", ")
    }
}
