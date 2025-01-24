import SwiftUI
import CoreData

struct LearnPathNavigator: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isAnimating = false
    @State private var hoveringPath: String?
    @State private var selectedPath: LearningPath?
    
    private let paths = PathTheme.allPaths
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                progressOverview
                    .fadeInTransition(active: !isAnimating)
                
                Divider()
                    .opacity(isAnimating ? 1 : 0)
                
                learningPaths
                
                recommendedPath
                    .fadeInTransition(active: !isAnimating)
            }
            .padding()
        }
        .navigationTitle("Learning Paths")
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
        .sheet(item: $selectedPath) { path in
            LearnPathDetail(path: path)
        }
    }
    
    private var progressOverview: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Journey")
                        .font(.headline)
                    Text("Continue your learning path")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                NavigationLink(destination: LearnProgressView()) {
                    Label("Stats", systemImage: "chart.bar.fill")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            
            ProgressGrid()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var learningPaths: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Paths")
                .font(.headline)
                .fadeInTransition(active: !isAnimating)
            
            ForEach(Array(paths.enumerated()), id: \.1.id) { index, path in
                PathRow(
                    path: path,
                    isHovered: hoveringPath == path.id,
                    progress: LearningPathManager.shared.calculatePathProgress(
                        pathId: path.id,
                        context: viewContext
                    )
                )
                .onTapGesture {
                    withAnimation {
                        selectedPath = path
                    }
                }
                .onHover { hovering in
                    withAnimation(.spring()) {
                        hoveringPath = hovering ? path.id : nil
                    }
                }
                .fadeInTransition(active: !isAnimating)
                .animation(.easeInOut.delay(Double(index) * 0.15), value: isAnimating)
            }
        }
    }
    
    private var recommendedPath: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended Next")
                .font(.headline)
            
            RecommendedPathCard(path: PathTheme.advanced)
        }
    }
}

struct PathRow: View {
    let path: LearningPath
    let isHovered: Bool
    let progress: Double
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: path.systemIcon)
                .font(.title2)
                .foregroundColor(path.color)
                .frame(width: 32)
                .scaleEffect(isHovered ? 1.1 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(path.name)
                        .font(.headline)
                    
                    if progress > 0 {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(path.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if progress > 0 {
                LearnProgressAnimation(progress: progress, color: path.color)
                    .frame(width: 24, height: 24)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .opacity(isHovered ? 1 : 0.5)
                .offset(x: isHovered ? 5 : 0)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .offset(x: isHovered ? 5 : 0)
        .animation(.spring(), value: isHovered)
    }
}

struct RecommendedPathCard: View {
    let path: LearningPath
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(path.name, systemImage: path.systemIcon)
                .font(.headline)
                .foregroundColor(path.color)
            
            Text(path.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Label("4 Articles", systemImage: "doc.text")
                Label("2 Quizzes", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Button(action: {}) {
                Text("Start Path")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(path.color)
                    .cornerRadius(12)
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(), value: isHovered)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ProgressGrid: View {
    @State private var isAnimating = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            StatCard(
                title: "Articles", 
                value: "12", 
                subtitle: "Read",
                delay: 0.0
            )
            StatCard(
                title: "Quizzes", 
                value: "8", 
                subtitle: "Completed",
                delay: 0.1
            )
            StatCard(
                title: "Streak", 
                value: "5", 
                subtitle: "Days",
                delay: 0.2
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let delay: Double
    
    @State private var isAnimating = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .scaleEffect(isHovered ? 1.1 : 1.0)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.spring()) {
                isHovered = hovering
            }
        }
        .scaleEffect(isAnimating ? 1 : 0.8)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring().delay(delay)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    NavigationView {
        LearnPathNavigator()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}