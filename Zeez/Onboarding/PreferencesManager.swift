import Foundation
import CoreData
import Combine
import os.log

@MainActor
final class PreferencesManager: ObservableObject {
    private let context: NSManagedObjectContext
    
    @Published private(set) var preferences: UserPreferences?
    @Published private(set) var loadingState: LoadingState = .idle
    
    private var cancellables = Set<AnyCancellable>()
    
    enum LoadingState {
        case idle
        case loading
        case loaded
        case error(Error)
    }
    
    enum PreferencesError: LocalizedError {
        case failedToSave(underlying: Error)
        case invalidData
        case notFound
        
        var errorDescription: String? {
            switch self {
            case .failedToSave(let error):
                return "Failed to save preferences: \(error.localizedDescription)"
            case .invalidData:
                return "Invalid preferences data"
            case .notFound:
                return "No preferences found"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .failedToSave:
                return "Please try again or restart the app"
            case .invalidData:
                return "Check your input values and try again"
            case .notFound:
                return "Complete onboarding to set up preferences"
            }
        }
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
        loadPreferences()
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .filter { [weak self] note in
                note.object as? NSManagedObjectContext == self?.context
            }
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadPreferences()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadPreferences() {
        loadingState = .loading
        let request = UserPreferences.fetchRequest()
        request.fetchLimit = 1
        
        do {
            preferences = try context.fetch(request).first
            loadingState = .loaded
        } catch {
            loadingState = .error(PreferencesError.failedToSave(underlying: error))
        }
    }
    
    @discardableResult
    func savePreferences(
        targetSleepDuration: Double,
        targetWakeTime: Date,
        healthKitEnabled: Bool = false,
        notificationsEnabled: Bool = false
    ) async throws -> UserPreferences {
        let preferences = UserPreferences(context: context)
        preferences.id = UUID()
        preferences.targetSleepDuration = targetSleepDuration
        preferences.targetWakeTime = targetWakeTime
        preferences.targetBedtime = Calendar.current.date(
            byAdding: .hour,
            value: -Int(targetSleepDuration),
            to: targetWakeTime
        )
        preferences.sleepGoalEnabled = true
        preferences.healthKitSyncEnabled = healthKitEnabled
        preferences.notificationsEnabled = notificationsEnabled
        preferences.createdAt = Date()
        preferences.modifiedAt = Date()
        
        do {
            try context.save()
            self.preferences = preferences
            return preferences
        } catch {
            throw PreferencesError.failedToSave(underlying: error)
        }
    }
    
    func updatePreferences(_ updates: (UserPreferences) throws -> Void) async throws {
        guard let preferences = preferences else {
            throw PreferencesError.notFound
        }
        
        do {
            try updates(preferences)
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw PreferencesError.failedToSave(underlying: error)
        }
    }
    
    func deletePreferences() async throws {
        guard let preferences = preferences else {
            throw PreferencesError.notFound
        }
        
        context.delete(preferences)
        
        do {
            try context.save()
            self.preferences = nil
        } catch {
            throw PreferencesError.failedToSave(underlying: error)
        }
    }
}
