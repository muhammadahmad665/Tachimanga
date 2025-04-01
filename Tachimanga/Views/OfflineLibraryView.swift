import SwiftUI

struct OfflineLibraryView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var availableManga: [Manga] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading offline library...")
            } else if availableManga.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("No Offline Content Available")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("You're offline and don't have any downloaded manga. Connect to the internet to browse and download manga for offline reading.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(availableManga) { manga in
                            NavigationLink(destination: MangaDetailView(mangaId: manga.id)) {
                                MangaGridItem(manga: manga)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Offline Library")
        .onAppear {
            loadOfflineAvailableManga()
        }
    }
    
    private func loadOfflineAvailableManga() {
        isLoading = true
        availableManga = []
        
        // Get manga IDs that have downloaded chapters
        let mangaIds = Array(downloadManager.downloadedItems.keys)
        guard !mangaIds.isEmpty else {
            isLoading = false
            return
        }
        
        // Load each manga's details
        let repository = ServiceProvider.shared.mangaRepository
        
        var loadedManga: [Manga] = []
        var loadCount = 0
        let totalCount = mangaIds.count
        
        for mangaId in mangaIds {
            repository.fetchMangaDetails(id: mangaId)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in
                        loadCount += 1
                        if loadCount == totalCount {
                            availableManga = loadedManga.sorted { $0.title < $1.title }
                            isLoading = false
                        }
                    },
                    receiveValue: { manga in
                        loadedManga.append(manga)
                    }
                )
                .store(in: &downloadManager.cancellables)
        }
    }
}

struct DownloadedMangaRow: View {
    let manga: DownloadedManga
    
    var body: some View {
        HStack(spacing: 16) {
            // Cover image
            Group {
                if let url = manga.coverImageURL {
                    Image(uiImage: UIImage(contentsOfFile: url.path) ?? UIImage(systemName: "book.closed")!)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "book.closed")
                        .padding()
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 70, height: 100)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(manga.title)
                    .font(.headline)
                
                Text("\(manga.chapters.count) chapter\(manga.chapters.count > 1 ? "s" : "") downloaded")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Size info
                Text("\(viewModel.sizeString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var viewModel: DownloadedMangaSizeViewModel {
        DownloadedMangaSizeViewModel(mangaID: manga.id)
    }
}

struct DownloadedMangaDetailView: View {
    let manga: DownloadedManga
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        List {
            Section(header: Text("Downloaded Chapters").font(.headline)) {
                ForEach(manga.chapters.sorted(by: { $0.chapterNumber < $1.chapterNumber }), id: \.chapterID) { chapter in
                    NavigationLink(destination: OfflineChapterReaderView(
                        mangaID: chapter.mangaID,
                        chapterID: chapter.chapterID,
                        chapterNumber: chapter.chapterNumber,
                        chapterTitle: chapter.chapterTitle
                    )) {
                        DownloadedChapterRow(chapter: chapter)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            DownloadManager.shared.deleteDownload(mangaID: chapter.mangaID, chapterID: chapter.chapterID)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(manga.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("Delete All Downloads?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                for chapter in manga.chapters {
                    DownloadManager.shared.deleteDownload(mangaID: chapter.mangaID, chapterID: chapter.chapterID)
                }
            }
        } message: {
            Text("All downloaded chapters will be permanently deleted.")
        }
    }
}

struct DownloadedChapterRow: View {
    let chapter: DownloadedChapter
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Chapter \(String(format: "%.1f", chapter.chapterNumber))")
                .font(.headline)
            
            if let title = chapter.chapterTitle, !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
                
                Text("Downloaded \(formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: chapter.downloadDate, relativeTo: Date())
    }
}

class OfflineLibraryViewModel: ObservableObject {
    @Published var downloadedManga: [DownloadedManga] = []
    @Published var isLoading = false
    
    func loadDownloadedManga() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let manga = DownloadManager.shared.getDownloadedManga()
            
            DispatchQueue.main.async {
                self?.downloadedManga = manga
                self?.isLoading = false
            }
        }
    }
}

class DownloadedMangaSizeViewModel {
    private let mangaID: String
    
    init(mangaID: String) {
        self.mangaID = mangaID
    }
    
    var sizeString: String {
        let size = calculateSize()
        return formatFileSize(size)
    }
    
    private func calculateSize() -> Int64 {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mangaURL = documentsURL.appendingPathComponent("Downloads/\(mangaID)", isDirectory: true)
        
        guard fileManager.fileExists(atPath: mangaURL.path) else {
            return 0
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: mangaURL, includingPropertiesForKeys: [.fileSizeKey])
            return try contents.reduce(0) { (result, url) in
                let attributes = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                
                if attributes.isDirectory == true {
                    // If it's a directory, recursively calculate its size
                    let dirContents = try fileManager.contentsOfDirectory(
                        at: url, 
                        includingPropertiesForKeys: [.fileSizeKey]
                    )
                    
                    let dirSize = try dirContents.reduce(0) { (subResult, subUrl) in
                        let fileSize = try subUrl.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        return subResult + Int(Int64(fileSize))
                    }
                    
                    return result + Int64(dirSize)
                } else {
                    // If it's a file, add its size
                    return result + Int64(attributes.fileSize ?? 0)
                }
            }
        } catch {
            print("Error calculating size: \(error)")
            return 0
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: size)
    }
}

struct OfflineChapterReaderView: View {
    let mangaID: String
    let chapterID: String
    let chapterNumber: Double
    let chapterTitle: String?
    
    @State private var pageURLs: [URL] = []
    @State private var currentPage = 0
    
    @AppStorage("readerDirection") private var readerDirection: ReaderDirection = .leftToRight
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if pageURLs.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                switch readerDirection {
                case .leftToRight, .rightToLeft:
                    TabView(selection: $currentPage) {
                        ForEach(Array(pageURLs.enumerated()), id: \.0) { index, url in
                            OfflineImageView(url: url)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .background(Color.black)
                
                case .vertical:
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            ForEach(Array(pageURLs.enumerated()), id: \.0) { index, url in
                                OfflineImageView(url: url)
                            }
                        }
                    }
                }
                
                VStack {
                    Spacer()
                    Text("\(currentPage + 1) / \(pageURLs.count)")
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.bottom)
                }
            }
        }
        .navigationTitle("Chapter \(String(format: "%.1f", chapterNumber))")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadImages()
        }
    }
    
    private func loadImages() {
        if let urls = DownloadManager.shared.getDownloadedChapterUrls(mangaID: mangaID, chapterID: chapterID) {
            self.pageURLs = urls
        }
    }
}

struct OfflineImageView: View {
    let url: URL
    @State private var image: UIImage? = nil
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url),
               let loadedImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        OfflineLibraryView()
    }
}
