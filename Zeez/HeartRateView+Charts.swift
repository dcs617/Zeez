import SwiftUI
import Charts

extension HeartRateView {
    func heartRateChartSection(data: [HeartRateData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            timeRangeHeader
            
            HeartRateChart(
                data: formatHeartRateData(data),
                selectedDataPoint: $selectedDataPoint
            )
            .frame(height: 200)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private var timeRangeHeader: some View {
        HStack {
            Text("Heart Rate Trend")
                .font(.headline)
            
            Spacer()
            
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(HeartRateTimeRange.allCases) { range in
                    Text(range.label)
                        .tag(range)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    func heartRateVariabilitySection(data: [HeartRateData]) -> some View {
        let hrv = calculateHRV(data: data)
        return hrvContent(hrv: hrv)
    }
    
    private func hrvContent(hrv: HRVData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Variability")
                .font(.headline)
            
            HRVChart(data: hrv.timeData)
                .frame(height: 150)
            
            HRVInsightsView(averageHRV: hrv.average, quality: hrv.quality)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    func heartRateZonesSection(data: [HeartRateData]) -> some View {
        let zones = calculateHeartRateZones(data: data)
        return zonesContent(zones: zones)
    }
    
    private func zonesContent(zones: [HeartRateZone]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Zones")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(zones) { zone in
                    HeartRateZoneRow(zone: zone)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    func sleepStageCorrelationSection(heartRateData: [HeartRateData], stages: [SleepStage]) -> some View {
        let correlations = calculateStageCorrelation(heartRateData: heartRateData, stages: stages)
        return correlationContent(correlations: correlations)
    }
    
    private func correlationContent(correlations: [StageCorrelation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stage Correlation")
                .font(.headline)
            
            correlationsList(correlations: correlations)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func correlationsList(correlations: [StageCorrelation]) -> some View {
        VStack(spacing: 16) {
            ForEach(correlations) { correlation in
                correlationRow(correlation: correlation, isLast: correlation.id == correlations.last?.id)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
        }
    }
    
    private func correlationRow(correlation: StageCorrelation, isLast: Bool) -> some View {
        VStack {
            SleepStageCorrelationRow(
                stageName: correlation.stageName,
                averageHR: correlation.averageHR,
                timeSpent: correlation.timeSpent,
                color: correlation.color
            )
            
            if !isLast {
                Divider()
            }
        }
    }
}
