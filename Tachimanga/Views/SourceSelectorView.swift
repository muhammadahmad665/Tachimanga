import SwiftUI
import Combine

struct SourceSelectorView: View {
    @State private var sources: [MangaSource] = []
    @State private var currentSource: MangaSource?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Use @StateObject to store cancellables, which makes it a reference type that can be modified
    @StateObject private var viewModel = SourceSelectorViewModel()
    
    // Callback when source changes
    var onSourceChanged: (MangaSource) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading sources...")
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error loading sources")
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding(.bottom, 4)
                        
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            loadSources()
                        }
                        .padding(.top)
                        .foregroundColor(.blue)
                    }
                } else {
                    List {
                        ForEach(sources) { source in
                            Button(action: {
                                switchToSource(source)
                            }) {
                                HStack {
                                    Image(systemName: source.icon)
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    Text(source.name)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    if source.id == currentSource?.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Section(header: Text("About Sources")) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Sources are providers of manga content. Different sources may have different manga catalogs, languages, and features.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Select Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSources()
        }
    }
    
    private func loadSources() {
        isLoading = true
        errorMessage = nil
        
        // Get available sources
        viewModel.repository.getAvailableSources()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                        isLoading = false
                    }
                },
                receiveValue: { sources in
                    self.sources = sources
                    
                    // Get current source
                    viewModel.repository.getCurrentSource()
                        .receive(on: DispatchQueue.main)
                        .sink(
                            receiveCompletion: { completion in
                                isLoading = false
                                if case .failure(let error) = completion {
                                    errorMessage = error.localizedDescription
                                }
                            },
                            receiveValue: { source in
                                currentSource = source
                                isLoading = false
                            }
                        )
                        .store(in: &viewModel.cancellables)
                }
            )
            .store(in: &viewModel.cancellables)
    }
    
    private func switchToSource(_ source: MangaSource) {
        guard source.id != currentSource?.id else {
            // No need to switch if it's already the current source
            dismiss()
            return
        }
        
        isLoading = true
        
        viewModel.repository.switchSource(sourceId: source.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { success in
                    if success {
                        currentSource = source
                        onSourceChanged(source)
                        dismiss()
                    }
                }
            )
            .store(in: &viewModel.cancellables)
    }
}

// Create a view model class to hold state that needs to be mutable
class SourceSelectorViewModel: ObservableObject {
    var repository: MangaRepository = ServiceProvider.shared.mangaRepository
    var cancellables = Set<AnyCancellable>()
}

#Preview {
    SourceSelectorView { _ in
        // Source changed handler
    }
}
