import SwiftUI
import Combine

struct ReadingHistoryView: View {
    @StateObject private var viewModel = ReadingHistoryViewModel()
    // Add refresh control
    let refreshControl = RefreshControlCoordinator(action: {
        // This will be set later
    })
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if viewModel.readingHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Text("No reading history yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Start reading manga to track your progress")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding()
                } else {
                    ForEach(viewModel.groupedHistory.keys.sorted(by: >), id: \.self) { date in
                        if let entries = viewModel.groupedHistory[date] {
                            Section(header: 
                                HStack {
                                    Text(formatDate(date))
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    if Calendar.current.isDateInToday(date) || Calendar.current.isDateInYesterday(date) {
                                        Button(action: {
                                            viewModel.clearDayHistory(date: date)
                                        }) {
                                            Text("Clear")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            ) {
                                ForEach(entries) { historyEntry in
                                    ReadingHistoryRow(
                                        entry: historyEntry,
                                        manga: viewModel.getManga(for: historyEntry.mangaId),
                                        onDelete: {
                                            viewModel.removeHistoryEntry(entry: historyEntry)
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(RefreshControl(coordinator: refreshControl))
        .navigationTitle("Reading History")
        .toolbar {
            if !viewModel.readingHistory.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showClearAlert = true
                    }) {
                        Text("Clear All")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert("Clear Reading History", isPresented: $viewModel.showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                viewModel.clearAllHistory()
            }
        } message: {
            Text("This will remove all your reading history. This action cannot be undone.")
        }
        .onAppear {
            viewModel.loadHistory()
            refreshControl.action = viewModel.loadHistory
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

struct ReadingHistoryRow: View {
    let entry: ReadingHistoryEntry
    let manga: Manga?
    let onDelete: () -> Void
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 12) {
                // Cover image
                Group {
                    if let manga = manga, let url = manga.coverImageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Image(systemName: "book.closed")
                                    .padding()
                                    .foregroundColor(.secondary)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "book.closed")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 60, height: 90)
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Manga title
                    Text(manga?.title ?? "Unknown Manga")
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Chapter info
                    if let chapter = getChapter() {
                        Text("Chapter \(String(format: "%.1f", chapter.number))")
                            .font(.subheadline)
                        
                        // Progress indicator
                        HStack(spacing: 4) {
                            if entry.isCompleted {
                                Label("Completed", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Text("Page \(entry.lastPageRead + 1)")
                            }
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            // Time read
                            Text(entry.dateAccessed.timeAgo())
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Continue reading button
                if !entry.isCompleted {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var destinationView: some View {
        Group {
            if let chapter = getChapter() {
                ChapterReaderView(chapter: chapter)
            } else {
                // Fallback to manga detail if chapter can't be found
                if let manga = manga {
                    MangaDetailView(mangaId: manga.id)
                } else {
                    Text("Content not available")
                        .navigationTitle("Not Available")
                }
            }
        }
    }
    
    private func getChapter() -> Chapter? {
        return manga?.chapters.first { $0.id == entry.chapterId }
    }
}

class ReadingHistoryViewModel: ObservableObject {
    @Published var readingHistory: [ReadingHistoryEntry] = []
    @Published var mangaCache: [String: Manga] = [:]
    @Published var isLoading = false
    @Published var groupedHistory: [Date: [ReadingHistoryEntry]] = [:]
    @Published var showClearAlert = false
    
    private let repository: MangaRepository = MockMangaRepository()
    private var cancellables = Set<AnyCancellable>()
    
    func loadHistory() {
        isLoading = true
        
        repository.getReadingHistory()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                },
                receiveValue: { [weak self] entries in
                    self?.readingHistory = entries
                    self?.groupHistoryByDate()
                    self?.loadMangaDetails(from: entries)
                }
            )
            .store(in: &cancellables)
    }
    
    func groupHistoryByDate() {
        // Group by date without time
        let calendar = Calendar.current
        var groupedEntries: [Date: [ReadingHistoryEntry]] = [:]
        
        for entry in readingHistory {
            // Get date components for day, month, year
            let components = calendar.dateComponents([.year, .month, .day], from: entry.dateAccessed)
            // Create a new date with just day, month, year
            if let date = calendar.date(from: components) {
                if groupedEntries[date] != nil {
                    groupedEntries[date]?.append(entry)
                } else {
                    groupedEntries[date] = [entry]
                }
            }
        }
        
        self.groupedHistory = groupedEntries
    }
    
    private func loadMangaDetails(from entries: [ReadingHistoryEntry]) {
        // Get unique manga IDs
        let mangaIds = Set(entries.map { $0.mangaId })
        
        // Load details for each manga
        for mangaId in mangaIds {
            repository.fetchMangaDetails(id: mangaId)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { [weak self] manga in
                        self?.mangaCache[mangaId] = manga
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    func getManga(for id: String) -> Manga? {
        return mangaCache[id]
    }
    
    func clearAllHistory() {
        repository.clearReadingHistory()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    self?.readingHistory = []
                    self?.groupedHistory = [:]
                }
            )
            .store(in: &cancellables)
    }
    
    func clearDayHistory(date: Date) {
        let calendar = Calendar.current
        readingHistory.removeAll { entry in
            calendar.isDate(entry.dateAccessed, inSameDayAs: date)
        }
        groupHistoryByDate()
    }
    
    func removeHistoryEntry(entry: ReadingHistoryEntry) {
        readingHistory.removeAll { $0.id == entry.id }
        groupHistoryByDate()
    }
}

#Preview {
    NavigationView {
        ReadingHistoryView()
    }
}
