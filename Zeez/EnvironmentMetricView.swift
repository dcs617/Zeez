import SwiftUI

struct EnvironmentMetricView: View {
    let icon: String
    let label: String
    let value: String
    let rating: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(label)
                    .font(.subheadline)
            }
            
            HStack {
                Text(value)
                    .font(.title3)
                    .bold()
                
                Spacer()
                
                Text(rating)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ratingColor.opacity(0.2))
                    .foregroundStyle(ratingColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
        }
    }
    
    private var ratingColor: Color {
        switch rating {
        case "Optimal": return .green
        case "Good": return .blue
        case "Fair": return .orange
        default: return .red
        }
    }
}

#Preview {
    EnvironmentMetricView(
        icon: "thermometer",
        label: "Temperature",
        value: "20°C",
        rating: "Optimal"
    )
    .padding()
    .background(Color(.systemGray6))
}
