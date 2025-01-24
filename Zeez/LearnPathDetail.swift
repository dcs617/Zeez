import SwiftUI
import CoreData

struct LearnPathDetail: View {
    @Environment(\.managedObjectContext) private var viewContext
    let path: LearningPath
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                pathHeader
                    .fadeInTransition(active: !isAnimating)
                
                Divider()
                
                let modules = LearningPathManager.shared.getPathArticles(
                    pathId: path.id, 
                    context: viewContext
                )
                
                VStack(spacing: 24) {
                    ForEach(Array(modules.enumerated()), id: \.1.id) { index, article in
                        NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                            ModuleCard(
                                title: article.title ?? "",
                                description: "Learn about " + (article.title?.lowercased() ?? ""),
                                duration: Int(article.readTimeMinutes),
                                type: .article,
                                isCompleted: article.userProgress?.isCompleted ?? false,
                                isLocked: false,
                                delay: Double(index) * 0.1
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(path.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
    
    private var pathHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: path.systemIcon)
                    .font(.largeTitle)
                    .foregroundColor(path.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(path.description)
                        .font(.headline)
                    
                    Text("Estimated completion: 2-3 hours")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            PathProgressView(pathId: path.id)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ModuleCard: View {
    let title: String
    let description: String
    let duration: Int
    let type: ModuleType
    let isCompleted: Bool
    let isLocked: Bool
    let delay: Double
    
    @State private var isAnimating = false
    @State private var isHovered = false
    
    enum ModuleType {
        case article, quiz, exercise, video
        
        var icon: String {
            switch self {
            case .article: return "doc.text"
            case .quiz: return "checkmark.circle"
            case .exercise: return "figure.walk"
            case .video: return "play.circle"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(isLocked ? .gray : .blue)
                .frame(width: 32)
                .scaleEffect(isHovered ? 1.1 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isLocked ? .gray : .primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label("\(duration) min", systemImage: "clock")
                    
                    if isCompleted {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0.5)
                    .offset(x: isHovered ? 5 : 0)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(isLocked ? 0.7 : 1)
        .scaleEffect(isAnimating ? 1 : 0.9)
        .opacity(isAnimating ? 1 : 0)
        .offset(x: isAnimating ? 0 : -20)
        .onAppear {
            withAnimation(.spring().delay(delay)) {
                isAnimating = true
            }
        }
        .onHover { hovering in
            withAnimation(.spring()) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    NavigationView {
        LearnPathDetail(path: PathTheme.basics)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}