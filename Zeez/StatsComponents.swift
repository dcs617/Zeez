import SwiftUI

struct TimeRangeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct ChartSection<Content: View>: View {
    let title: String
    let showMore: Bool
    let content: Content
    
    init(title: String, showMore: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showMore = showMore
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if showMore {
                    Button(action: {}) {
                        Text("More")
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            
            content
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct SleepQualityChart: View {
    let data: [(date: Date, quality: Double)]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: geometry.size.width / CGFloat(max(14, data.count * 2))) {
                ForEach(data, id: \.date) { dataPoint in
                    VStack(spacing: 4) {
                        // Quality bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(qualityColor(dataPoint.quality))
                            .frame(width: 8, height: geometry.size.height * dataPoint.quality / 100)
                        
                        // Date label
                        Text(formatDate(dataPoint.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    private func qualityColor(_ quality: Double) -> Color {
        switch quality {
        case 0..<60: return .red
        case 60..<80: return .yellow
        default: return .green
        }
    }
}

struct SleepScheduleChart: View {
    let data: [(hour: Int, sleepProbability: Double)]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hour grid lines
                ForEach(0..<24) { hour in
                    if hour % 3 == 0 {
                        HStack {
                            Text("\(hour):00")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 1)
                        }
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height * CGFloat(hour) / 24
                        )
                    }
                }
                
                // Sleep probability curve
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    guard let first = data.first else { return }
                    path.move(to: CGPoint(
                        x: 0,
                        y: height * (1 - first.sleepProbability)
                    ))
                    
                    for i in 1..<data.count {
                        let point = CGPoint(
                            x: width * CGFloat(i) / CGFloat(data.count - 1),
                            y: height * (1 - data[i].sleepProbability)
                        )
                        
                        let control1 = CGPoint(
                            x: width * CGFloat(i - 1) / CGFloat(data.count - 1),
                            y: height * (1 - data[i - 1].sleepProbability)
                        )
                        
                        let control2 = CGPoint(
                            x: width * CGFloat(i) / CGFloat(data.count - 1),
                            y: height * (1 - data[i].sleepProbability)
                        )
                        
                        path.addCurve(to: point, control1: control1, control2: control2)
                    }
                }
                .stroke(Color.purple, lineWidth: 2)
                
                // Fill area under curve
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    guard let first = data.first else { return }
                    path.move(to: CGPoint(x: 0, y: height))
                    path.addLine(to: CGPoint(
                        x: 0,
                        y: height * (1 - first.sleepProbability)
                    ))
                    
                    for i in 1..<data.count {
                        let point = CGPoint(
                            x: width * CGFloat(i) / CGFloat(data.count - 1),
                            y: height * (1 - data[i].sleepProbability)
                        )
                        path.addLine(to: point)
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(Color.purple.opacity(0.1))
            }
        }
    }
}