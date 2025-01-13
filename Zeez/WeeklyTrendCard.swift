//
//  WeeklyTrendCard.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
import SwiftUI

struct WeeklyTrendCard: View {
    let sessions: [SleepSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Trend")
                .font(.headline)
            
            Chart(sessions: sessions)
                .frame(height: 150)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}
