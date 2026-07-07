import SwiftUI
import os.log

/// Displays average environmental readings for a sleep session
struct AverageEnvironmentalReadingView: View {
    let readings: [EnvironmentalReading]
    
    /// Per-metric averages over genuinely measured values only; nil when a
    /// metric was never measured (see EnvironmentalReading.notMeasured, 2.9).
    private var averages: (noise: Double?, light: Double?, temp: Double?) {
        func average(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        return (
            noise: average(readings.compactMap(\.measuredNoiseLevel)),
            light: average(readings.compactMap(\.measuredLightLevel)),
            temp: average(readings.compactMap(\.measuredTemperature))
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            if averages.noise == nil && averages.light == nil && averages.temp == nil {
                Text("No environmental measurements")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                if let noise = averages.noise {
                    environmentalMetric(
                        icon: "ear",
                        title: "Noise",
                        value: noise,
                        unit: "dB",
                        color: .blue
                    )
                }

                if let light = averages.light {
                    environmentalMetric(
                        icon: "lightbulb",
                        title: "Light",
                        value: light,
                        unit: "lux",
                        color: .yellow
                    )
                }
            }

            if let temp = averages.temp {
                environmentalMetric(
                    icon: "thermometer",
                    title: "Temperature",
                    value: temp,
                    unit: "°C",
                    color: .red
                )
            }
        }
    }
    
    private func environmentalMetric(
        icon: String,
        title: String,
        value: Double,
        unit: String,
        color: Color
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", value))
                        .font(.title3)
                        .bold()
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AverageEnvironmentalReadingView_Previews: PreviewProvider {
    static var previews: some View {
        AverageEnvironmentalReadingView(readings: [])
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
