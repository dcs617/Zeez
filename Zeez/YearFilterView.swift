import SwiftUI

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
                            }
                        }
                    }
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
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter by Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    YearFilterView(selectedYear: .constant(2024), years: [2024, 2023, 2022])
}