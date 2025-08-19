//
//  LearnCircadianRhythmView.swift
//  Zeez
//
//  Created by Daniel on 1/18/25.
//
import SwiftUI
import os.log

struct LearnCircadianRhythmView: View {
    @State private var selectedHour: Int = 12
    @State private var showingDetailView = false
    @State private var isDragging = false
    
    private let hourMarkers = Array(0...23)
    private let markerWidth: CGFloat = 2
    private let markerHeight: CGFloat = 10
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background
                circadianCurve
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(height: 200)
                
                // Time indicator
                timeMarker
                    .offset(x: getXPosition(for: selectedHour))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                updateSelectedHour(from: value)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Time selector at \(selectedHour):00")
                    .accessibilityHint("Drag to select a different time of day to explore circadian rhythm information")
                    .accessibilityIdentifier("timeMarker")
                
                // Hour markers
                ForEach(hourMarkers, id: \.self) { hour in
                    hourMarker(for: hour)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Circadian rhythm chart")
            .accessibilityHint("Interactive chart showing circadian rhythm patterns throughout the day")
            .accessibilityIdentifier("circadianChart")
            
            // Current time information
            timeInformation
                .padding()
            
            // Detailed information button
            detailButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Circadian rhythm view")
        .accessibilityHint("Learn about your body's natural daily rhythms")
        .accessibilityIdentifier("circadianRhythmView")
        .sheet(isPresented: $showingDetailView) {
            CircadianDetailView(hour: selectedHour)
        }
    }
    
    private var circadianCurve: Path {
        Path { path in
            let width = UIScreen.main.bounds.width - 40
            let height: CGFloat = 200
            let midHeight = height / 2
            
            path.move(to: CGPoint(x: 0, y: midHeight))
            
            // Create a sine wave that represents the circadian rhythm
            for x in 0...Int(width) {
                let normalizedX = Double(x) / width
                let angle = normalizedX * 2 * .pi
                let y = sin(angle) * (midHeight / 2) + midHeight
                
                if x == 0 {
                    path.move(to: CGPoint(x: CGFloat(x), y: y))
                } else {
                    path.addLine(to: CGPoint(x: CGFloat(x), y: y))
                }
            }
        }
    }
    
    private var timeMarker: some View {
        VStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .foregroundColor(.blue)
                .background(
                    Circle()
                        .fill(Color.white)
                        .shadow(radius: 2)
                )
            
            Text("\(selectedHour):00")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Selected time: \(selectedHour):00")
        .accessibilityIdentifier("selectedTimeDisplay")
        .offset(y: getYPosition(for: selectedHour))
    }
    
    private func hourMarker(for hour: Int) -> some View {
        VStack(spacing: 4) {
            Rectangle()
                .frame(width: markerWidth, height: markerHeight)
                .foregroundColor(.gray.opacity(0.5))
            
            if hour % 3 == 0 {
                Text("\(hour)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .offset(x: getXPosition(for: hour))
    }
    
    private var timeInformation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("At \(selectedHour):00")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Information for \(selectedHour):00")
                .accessibilityIdentifier("timeInfoHeader")
            
            Text(getCircadianInfo(for: selectedHour))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityLabel("Circadian information: \(getCircadianInfo(for: selectedHour))")
                .accessibilityIdentifier("circadianInfoText")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("At \(selectedHour):00: \(getCircadianInfo(for: selectedHour))")
        .accessibilityIdentifier("timeInformation")
    }
    
    private var detailButton: some View {
        Button(action: { showingDetailView = true }) {
            Label("View Detailed Information", systemImage: "info.circle")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .accessibilityLabel("View detailed information")
        .accessibilityHint("Open detailed circadian rhythm information for the selected time")
        .accessibilityIdentifier("detailInfoButton")
    }
    
    private func updateSelectedHour(from gesture: DragGesture.Value) {
        let width = UIScreen.main.bounds.width - 40
        let normalizedX = gesture.location.x / width
        let hour = Int((normalizedX * 24).rounded())
        selectedHour = max(0, min(23, hour))
    }
    
    private func getXPosition(for hour: Int) -> CGFloat {
        let width = UIScreen.main.bounds.width - 40
        return width * (CGFloat(hour) / 24)
    }
    
    private func getYPosition(for hour: Int) -> CGFloat {
        let height: CGFloat = 200
        let midHeight = height / 2
        let normalizedHour = Double(hour) / 24
        let angle = normalizedHour * 2 * .pi
        return sin(angle) * (midHeight / 2)
    }
    
    private func getCircadianInfo(for hour: Int) -> String {
        switch hour {
        case 0...4:
            return "Deepest sleep period. Core body temperature at its lowest."
        case 5...7:
            return "Gradual awakening period. Melatonin production stopping."
        case 8...11:
            return "Peak alertness and concentration period."
        case 12...14:
            return "Natural dip in alertness. Common siesta period."
        case 15...18:
            return "Second wind of alertness and coordination."
        case 19...21:
            return "Beginning of melatonin production. Body preparing for sleep."
        case 22...23:
            return "Natural sleep window approaching. Body temperature dropping."
        default:
            return "Invalid time"
        }
    }
}

struct CircadianDetailView: View {
    let hour: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    hormoneLevelsSection
                    bodyTemperatureSection
                    recommendationsSection
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Done") { dismiss() }
                .accessibilityLabel("Done")
                .accessibilityHint("Close detailed circadian information")
                .accessibilityIdentifier("circadianDetailDoneButton")
            )
            .navigationTitle("Circadian Detail")
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(hour):00")
                .font(.title)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Time: \(hour):00")
                .accessibilityIdentifier("detailTimeHeader")
            Text(getTimeOfDay(for: hour))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityLabel("Time of day: \(getTimeOfDay(for: hour))")
                .accessibilityIdentifier("timeOfDay")
        }
    }
    
    private var hormoneLevelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hormone Levels")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Hormone levels section")
                .accessibilityIdentifier("hormoneLevelsHeader")
            Text(getHormoneLevels(for: hour))
                .font(.body)
                .accessibilityLabel("Hormone levels: \(getHormoneLevels(for: hour))")
                .accessibilityIdentifier("hormoneLevelsText")
        }
    }
    
    private var bodyTemperatureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Body Temperature")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Body temperature section")
                .accessibilityIdentifier("bodyTemperatureHeader")
            Text(getBodyTemperature(for: hour))
                .font(.body)
                .accessibilityLabel("Body temperature: \(getBodyTemperature(for: hour))")
                .accessibilityIdentifier("bodyTemperatureText")
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Recommendations section")
                .accessibilityIdentifier("recommendationsHeader")
            Text(getRecommendations(for: hour))
                .font(.body)
                .accessibilityLabel("Recommendations: \(getRecommendations(for: hour))")
                .accessibilityIdentifier("recommendationsText")
        }
    }
    
    private func getTimeOfDay(for hour: Int) -> String {
        switch hour {
        case 0...5: return "Night"
        case 6...11: return "Morning"
        case 12...17: return "Afternoon"
        case 18...23: return "Evening"
        default: return ""
        }
    }
    
    private func getHormoneLevels(for hour: Int) -> String {
        // Add hormone level information based on the hour
        switch hour {
        case 0...2:
            return "Peak melatonin production. Growth hormone release."
        // Add more cases as needed
        default:
            return "Stable hormone levels."
        }
    }
    
    private func getBodyTemperature(for hour: Int) -> String {
        // Add body temperature information based on the hour
        switch hour {
        case 0...4:
            return "Lowest body temperature of the day."
        // Add more cases as needed
        default:
            return "Normal body temperature range."
        }
    }
    
    private func getRecommendations(for hour: Int) -> String {
        // Add recommendations based on the hour
        switch hour {
        case 0...4:
            return "Ideal time for deep sleep. Avoid blue light and screens."
        // Add more cases as needed
        default:
            return "Maintain regular daily activities."
        }
    }
}
