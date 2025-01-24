import SwiftUI

struct ToolCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String?
    
    init(title: String, icon: String, color: Color, description: String? = nil) {
        self.title = title
        self.icon = icon
        self.color = color
        self.description = description
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    VStack {
        ToolCard(
            title: "Sample Tool",
            icon: "gearshape",
            color: .blue
        )
        
        ToolCard(
            title: "Sample Tool",
            icon: "gearshape",
            color: .blue,
            description: "This is a sample description for the tool card"
        )
    }
    .padding()
}