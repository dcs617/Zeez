import SwiftUI
import Charts
import os.log

struct HeartRateView: View {
    let session: SleepSession?
    @State var selectedTimeRange: HeartRateTimeRange = .all
    @State var selectedDataPoint: HeartRateDataPoint?
    
    var body: some View {
        ScrollView {
            if let session = session,
               let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
               !heartRateData.isEmpty {
                VStack(spacing: 20) {
                    currentStatsSection(data: heartRateData)
                    heartRateChartSection(data: heartRateData)
                }
                .padding()
            } else {
                noDataView
            }
        }
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 44))
                .foregroundColor(.red.opacity(0.5))
            
            Text("No Heart Rate Data Available")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Make sure you wear your Apple Watch during sleep to record heart rate data.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No heart rate data available")
        .accessibilityHint("Wear your Apple Watch during sleep to record heart rate data")
        .accessibilityIdentifier("noHeartRateDataView")
    }
    
    private func currentStatsSection(data: [HeartRateData]) -> some View {
        let stats = calculateBasicStats(data: data)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Recorded Heart Rate Summary")
                .font(.headline)

            Text("Values recorded during this session. Zeez is not assessing cardiovascular health or recovery.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 20) {
                HeartRateStatCard(
                    title: "Average",
                    value: Int(stats.average),
                    color: .blue
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Recorded average heart rate: \(Int(stats.average)) beats per minute")
                .accessibilityIdentifier("averageHeartRateCard")
                
                HeartRateStatCard(
                    title: "Minimum",
                    value: Int(stats.min),
                    color: .indigo
                )
                
                HeartRateStatCard(
                    title: "Maximum",
                    value: Int(stats.max),
                    color: .red
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    // Calculates basic stats for display
    private func calculateBasicStats(data: [HeartRateData]) -> HeartRateStats {
        let values = data.map { $0.value }
        return HeartRateStats(
            min: values.min() ?? 0,
            max: values.max() ?? 0,
            average: values.reduce(0, +) / Double(values.count)
        )
    }
    
}
