import SwiftUI
import os.log

struct YearFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedYear: Int?
    let years: [Int]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        selectedYear = nil
                        dismiss()
                    }) {
                        HStack {
                            Text("All Years")
                            
                            Spacer()
                            
                            if selectedYear == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityLabel("All Years")
                    .accessibilityHint(selectedYear == nil ? "Currently selected" : "Select to show all years")
                    .accessibilityIdentifier("allYearsOption")
                }
                
                Section("Select Year") {
                    ForEach(years, id: \.self) { year in
                        Button(action: {
                            selectedYear = year
                            dismiss()
                        }) {
                            HStack {
                                Text("\(year)")
                                
                                Spacer()
                                
                                if selectedYear == year {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityLabel("Year \(year)")
                        .accessibilityHint(selectedYear == year ? "Currently selected" : "Select to filter by year \(year)")
                        .accessibilityIdentifier("yearOption_\(year)")
                    }
                }
            }
            .navigationTitle("Filter by Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done selecting year")
                        .accessibilityIdentifier("yearFilterDone")
                }
            }
        }
    }
}

#Preview {
    YearFilterView(selectedYear: .constant(2024), years: [2024, 2023, 2022])
}
