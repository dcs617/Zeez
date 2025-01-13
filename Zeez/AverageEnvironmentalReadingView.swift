import SwiftUI

/// Displays average environmental readings for a sleep session
struct AverageEnvironmentalReadingView: View {
    let readings: [EnvironmentalReading]
    
    private var averages: (noise: Double, light: Double, temp: Double) {
        let count = Double(readings.count)
        guard count > 0 else { return (0, 0, 0) }
        
        let noiseSum = readings.reduce(0.0) { $0 + $1.noiseLevel }
        let lightSum = readings.reduce(0.0) { $0 + $1.lightLevel }
        let tempSum = readings.reduce(0.0) { $0 + $1.temperature }
        
        return (
            noise: noiseSum / count,
            light: lightSum / count,
            temp: tempSum / count
        )
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                environmentalMetric(
                    icon: "ear",
                    title: "Noise",
                    value: averages.noise,
                    unit: "dB",
                    color: .blue
                )
                
                environmentalMetric(
                    icon: "lightbulb",
                    title: "Light",
                    value: averages.light,
                    unit: "lux",
                    color: .yellow
                )
            }
            
            if averages.temp > 0 {
                environmentalMetric(
                    icon: "thermometer",
                    title: "Temperature",
                    value: averages.temp,
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