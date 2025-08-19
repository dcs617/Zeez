import SwiftUI
import CoreData
import os.log

struct FetchRequestView<T: NSFetchRequestResult, Content: View>: View {
    @FetchRequest var results: FetchedResults<T>
    let content: (FetchedResults<T>) -> Content
    
    init(fetchRequest: NSFetchRequest<T>, @ViewBuilder content: @escaping (FetchedResults<T>) -> Content) {
        _results = FetchRequest(fetchRequest: fetchRequest)
        self.content = content
    }
    
    var body: some View {
        content(results)
            .accessibilityIdentifier("fetchRequestView")
    }
}
