import SwiftUI
import CoreData
import os.log

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

#Preview {
    NavigationStack {
        LearnPathNavigator()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
