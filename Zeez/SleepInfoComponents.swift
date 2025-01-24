import SwiftUI

struct SleepMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    var trend: TrendDirection?
    var comparisonText: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            metricHeader
            metricValue
            metricSubtitle
            metricComparison
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
        }
    }
    
    private var metricHeader: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var metricValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.title2)
                .bold()
                .foregroundStyle(color)
            
            if let trend = trend {
                Image(systemName: trend.icon)
                    .foregroundStyle(trend.color)
                    .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private var metricSubtitle: some View {
        if let subtitle = subtitle {
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var metricComparison: some View {
        if let comparison = comparisonText {
            Text(comparison)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
}

struct SleepEfficiencyRing: View {
    let efficiency: Double
    let size: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: efficiency / 100)
                .stroke(
                    efficiencyColor.gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
            
            // Label
            VStack(spacing: 4) {
                Text("\(Int(efficiency))%")
                    .font(.system(size: size * 0.25, weight: .bold))
                
                Text("Efficiency")
                    .font(.system(size: size * 0.12))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var efficiencyColor: Color {
        switch efficiency {
        case 90...: return .green
        case 70..<90: return .blue
        case 50..<70: return .yellow
        default: return .red
        }
    }
}

struct SleepFactorRow: View {
    let icon: String
    let title: String
    let value: String
    let rating: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .bold()
            
            Text(rating)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .foregroundStyle(color)
                .cornerRadius(8)
        }
    }
}

extension SleepSession {
    var timeAwake: TimeInterval {
        timeInBed - timeInSleep
    }
}
