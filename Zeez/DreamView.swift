import SwiftUI

/// Dream tab view for sleep aids and relaxation
struct DreamView: View {
    @State private var selectedCategory: Category = .all
    
    enum Category: String, CaseIterable {
        case all = "All"
        case ambient = "Ambient"
        case forKids = "For Kids"
        
        var icon: String {
            switch self {
            case .all: return "grid"
            case .ambient: return "sparkles"
            case .forKids: return "face.smiling"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Category.allCases, id: \.self) { category in
                                CategoryButton(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Content Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(sampleContent) { item in
                            ContentCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Discover")
            .overlay(
                NowPlayingBar()
                    .padding(.bottom),
                alignment: .bottom
            )
        }
    }
}

struct CategoryButton: View {
    let category: DreamView.Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: category.icon)
                Text(category.rawValue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct ContentItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageURL: String
    let duration: String
}

struct ContentCard: View {
    let item: ContentItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image placeholder with play button
            ZStack {
                Rectangle()
                    .fill(Color(UIColor.secondarySystemBackground))
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(12)
                
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            Text(item.title)
                .font(.subheadline)
                .bold()
            
            Text(item.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NowPlayingBar: View {
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Rectangle()
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(width: 40, height: 40)
                .cornerRadius(6)
            
            // Title and duration
            VStack(alignment: .leading) {
                Text("Holiday Recover")
                    .font(.subheadline)
                    .bold()
                Text("7 videos • 60min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {}) {
                    Image(systemName: "pause.fill")
                        .font(.title3)
                }
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
            }
            .foregroundColor(.primary)
        }
        .padding()
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
        )
    }
}

// Sample content for preview
private extension DreamView {
    var sampleContent: [ContentItem] {
        [
            ContentItem(title: "Holiday Recover", subtitle: "7 videos • 60min", imageURL: "", duration: "60min"),
            ContentItem(title: "Relax from stress", subtitle: "7 Songs • 34min", imageURL: "", duration: "34min"),
            ContentItem(title: "Daytime hacks", subtitle: "7 Songs • 60min", imageURL: "", duration: "60min"),
            ContentItem(title: "Relax the mind", subtitle: "7 Songs • 60min", imageURL: "", duration: "60min")
        ]
    }
}

struct DreamView_Previews: PreviewProvider {
    static var previews: some View {
        DreamView()
    }
}
