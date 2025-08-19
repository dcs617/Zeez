//
//  SleepDebtEducationCard.swift
//  Zeez
//
//  Created by Daniel on 1/22/25.
//
import SwiftUI
import os.log

struct SleepDebtEducationCard: View {
    let debt: TimeInterval
    let severity: DebtSeverity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Understanding Sleep Debt", systemImage: "book.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text(educationMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Learn More About Sleep Debt")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var educationMessage: String {
        switch severity {
        case .minimal:
            return "Learn how to maintain your healthy sleep patterns and prevent sleep debt"
        case .moderate:
            return "Discover strategies to reduce your sleep debt and improve sleep quality"
        case .significant:
            return "Understand the impacts of sleep debt and get help creating a recovery plan"
        case .severe:
            return "Holy shit you're almost dead!"
        }
    }
}
