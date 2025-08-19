import SwiftUI
import os.log

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
                            ForEach(Array(Category.allCases.enumerated()), id: \.element) { index, category in
                                CategoryButton(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                                .accessibilityLabel("\(category.rawValue) category")
                                .accessibilityHint(selectedCategory == category ? "Currently selected" : "Tap to filter content by \(category.rawValue)")
                                .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                                .accessibilityIdentifier("categoryButton_\(index)")
                            }
                        }
                        .padding(.horizontal)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Content categories")
                    .accessibilityIdentifier("categorySelector")
                    
                    // Content Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(Array(sampleContent.enumerated()), id: \.element.id) { index, item in
                            ContentCard(item: item)
                                .accessibilityIdentifier("contentCard_\(index)")
                        }
                    }
                    .padding(.horizontal)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Sleep content library")
                    .accessibilityIdentifier("contentGrid")
                }
            }
            .navigationTitle("Discover")
            .overlay(
                NowPlayingBar()
                    .padding(.bottom)
                    .accessibilityIdentifier("nowPlayingBar"),
                alignment: .bottom
            )
        }
        .accessibilityIdentifier("dreamView")
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
                    .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.rawValue) category filter")
        .accessibilityIdentifier("categoryButton_\(category.rawValue.lowercased())")
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
        Button(action: {
            // Play action would be implemented here
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Image placeholder with play button
                ZStack {
                    Rectangle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(12)
                        .accessibilityHidden(true)
                    
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .accessibilityHidden(true)
                }
                
                Text(item.title)
                    .font(.subheadline)
                    .bold()
                    .accessibilityHidden(true)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.subtitle)")
        .accessibilityHint("Tap to play sleep content")
        .accessibilityAddTraits(.startsMediaSession)
        .accessibilityIdentifier("contentCard_\(item.title.lowercased().replacingOccurrences(of: " ", with: ""))")
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
                .accessibilityHidden(true)
            
            // Title and duration
            VStack(alignment: .leading) {
                Text("Holiday Recover")
                    .font(.subheadline)
                    .bold()
                Text("7 videos • 60min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Now playing: Holiday Recover, 7 videos, 60 minutes")
            .accessibilityIdentifier("nowPlayingInfo")
            
            Spacer()
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {}) {
                    Image(systemName: "pause.fill")
                        .font(.title3)
                }
                .accessibilityLabel("Pause")
                .accessibilityHint("Pause the currently playing content")
                .accessibilityIdentifier("pauseButton")
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .accessibilityLabel("Next")
                .accessibilityHint("Skip to next content")
                .accessibilityIdentifier("nextButton")
            }
            .foregroundColor(.primary)
        }
        .padding()
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Media player controls")
        .accessibilityIdentifier("nowPlayingBarContainer")
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
