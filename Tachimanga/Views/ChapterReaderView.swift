import SwiftUI
import Combine

struct ChapterReaderView: View {
    let chapter: Chapter
    @StateObject private var viewModel = ChapterReaderViewModel()
    @State private var currentPage = 0
    @State private var showControls = true
    @State private var showChapterSelector = false
    @State private var showSettingsPanel = false
    @State private var zoomScale: ZoomScale = .fitToScreen
    
    // Reader preferences
    @AppStorage("readerDirection") private var readerDirection: ReaderDirection = .leftToRight
    @AppStorage("hideStatusBar") private var hideStatusBar = true
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading {
                    // Loading indicator
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let errorMessage = viewModel.errorMessage {
                    // Error view
                    VStack {
                        Text("Error loading chapter")
                            .foregroundColor(.white)
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.red)
                        Button("Retry") {
                            viewModel.loadChapterPages(mangaId: chapter.mangaId, chapterId: chapter.id)
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                } else if !viewModel.pageUrls.isEmpty {
                    // Content based on reading mode
                    Group {
                        switch readerDirection {
                        case .leftToRight:
                            leftToRightReader(geometry: geometry)
                        case .rightToLeft:
                            rightToLeftReader(geometry: geometry)
                        case .vertical:
                            verticalReader()
                        }
                    }
                    .onChange(of: currentPage) { newPage in
                        // Track reading progress
                        viewModel.updateReadingProgress(
                            mangaId: chapter.mangaId, 
                            chapterId: chapter.id, 
                            page: newPage
                        )
                    }
                    
                    // Reader controls overlay
                    if showControls {
                        readerControlsOverlay(geometry: geometry)
                    }
                    
                    // Tap gesture for toggling controls
                    Color.clear
                        .contentShape(Rectangle())
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
                }
            }
        }
        .navigationTitle("Chapter \(String(format: "%.1f", chapter.number))")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(hideStatusBar && !showControls)
        .statusBar(hidden: hideStatusBar && !showControls)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showSettingsPanel.toggle()
                }) {
                    Image(systemName: "gear")
                }
                .opacity(showControls ? 1 : 0)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showChapterSelector.toggle()
                }) {
                    Label("Chapters", systemImage: "list.bullet")
                        .labelStyle(.iconOnly)
                }
                .opacity(showControls ? 1 : 0)
            }
        }
        .onAppear {
            viewModel.loadChapterPages(mangaId: chapter.mangaId, chapterId: chapter.id)
            UIApplication.shared.isIdleTimerDisabled = keepScreenOn
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showChapterSelector) {
            ChapterSelectorView(
                mangaId: chapter.mangaId,
                currentChapterId: chapter.id
            )
        }
        .sheet(isPresented: $showSettingsPanel) {
            ReaderSettingsView(
                readerDirection: $readerDirection,
                hideStatusBar: $hideStatusBar,
                keepScreenOn: $keepScreenOn,
                zoomScale: $zoomScale
            )
        }
    }
    
    // MARK: - Reader Implementations
    
    private func leftToRightReader(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentPage) {
            ForEach(0..<viewModel.pageUrls.count, id: \.self) { index in
                ZoomableReaderPage(
                    url: viewModel.pageUrls[index],
                    zoomScale: zoomScale,
                    geometry: geometry
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
    
    private func rightToLeftReader(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentPage) {
            ForEach((0..<viewModel.pageUrls.count).reversed(), id: \.self) { index in
                ZoomableReaderPage(
                    url: viewModel.pageUrls[index],
                    zoomScale: zoomScale,
                    geometry: geometry
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
    
    private func verticalReader() -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(0..<viewModel.pageUrls.count, id: \.self) { index in
                    VerticalReaderPage(
                        url: viewModel.pageUrls[index],
                        zoomScale: zoomScale,
                        onPageAppear: { currentPage = index }
                    )
                }
            }
            .background(
                // Track scroll position with GeometryReader
                GeometryReader { geo -> Color in
                    let offset = geo.frame(in: .global).minY
                    DispatchQueue.main.async {
                        // Calculate approximate page based on scroll position
                        let pageHeight = geo.size.height / CGFloat(viewModel.pageUrls.count)
                        if pageHeight > 0 {
                            let estimatedPage = min(Int(-offset / pageHeight), viewModel.pageUrls.count - 1)
                            if estimatedPage >= 0 {
                                currentPage = estimatedPage
                            }
                        }
                    }
                    return Color.clear
                }
            )
        }
    }
    
    // MARK: - UI Components
    
    private func readerControlsOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            // Top bar (already handled by toolbar)
            Spacer()
            
            // Bottom controls bar
            HStack {
                // Previous chapter button
                Button(action: {
                    // Navigate to previous chapter
                    viewModel.navigateToPreviousChapter()
                }) {
                    Image(systemName: "chevron.left.2")
                        .foregroundColor(.white)
                        .padding()
                }
                .disabled(viewModel.previousChapter == nil)
                .opacity(viewModel.previousChapter == nil ? 0.5 : 1.0)
                
                Spacer()
                
                // Page indicator with slider
                VStack {
                    if readerDirection != .vertical {
                        Slider(value: Binding(
                            get: { Double(currentPage) },
                            set: { currentPage = Int($0) }
                        ), in: 0...Double(max(0, viewModel.pageUrls.count - 1)), step: 1)
                        .accentColor(.white)
                    }
                    
                    Text("\(currentPage + 1) / \(viewModel.pageUrls.count)")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .frame(maxWidth: geometry.size.width * 0.5)
                
                Spacer()
                
                // Next chapter button
                Button(action: {
                    // Navigate to next chapter
                    viewModel.navigateToNextChapter()
                }) {
                    Image(systemName: "chevron.right.2")
                        .foregroundColor(.white)
                        .padding()
                }
                .disabled(viewModel.nextChapter == nil)
                .opacity(viewModel.nextChapter == nil ? 0.5 : 1.0)
            }
            .padding(.horizontal)
            .padding(.bottom, geometry.safeAreaInsets.bottom)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.7))
                    .edgesIgnoringSafeArea(.bottom)
            )
        }
    }
}

// MARK: - Supporting Views

struct ZoomableReaderPage: View {
    let url: URL
    let zoomScale: ZoomScale
    let geometry: GeometryProxy
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: aspectRatio())
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    // Limit scale between 0.5 and 5
                                    scale = min(max(scale * delta, 0.5), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                        .onAppear {
                            // Reset scale and offset when page changes
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                case .failure:
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(.red)
                        
                        Text("Failed to load image")
                            .foregroundColor(.white)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
    
    private func aspectRatio() -> ContentMode {
        switch zoomScale {
        case .fitToScreen:
            return .fit
        case .fitToWidth:
            return .fill
        case .originalSize:
            return .fit // Original size is handled via scale
        }
    }
}

struct VerticalReaderPage: View {
    let url: URL
    let zoomScale: ZoomScale
    let onPageAppear: () -> Void
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onAppear(perform: onPageAppear)
            case .failure:
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .foregroundColor(.red)
                    
                    Text("Failed to load image")
                        .foregroundColor(.white)
                }
                .frame(height: 300)
            @unknown default:
                EmptyView()
            }
        }
        .background(Color.black)
    }
}

struct ChapterSelectorView: View {
    let mangaId: String
    let currentChapterId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChapterSelectorViewModel()
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    ForEach(viewModel.chapters) { chapter in
                        ChapterRow(chapter: chapter, isCurrentChapter: chapter.id == currentChapterId)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectChapter(chapter)
                                dismiss()
                            }
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadChapters(mangaId: mangaId)
        }
    }
    
    struct ChapterRow: View {
        let chapter: Chapter
        let isCurrentChapter: Bool
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chapter \(String(format: "%.1f", chapter.number))")
                        .foregroundColor(isCurrentChapter ? .blue : .primary)
                        .fontWeight(isCurrentChapter ? .bold : .regular)
                    
                    if let title = chapter.title, !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if chapter.isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                if isCurrentChapter {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct ReaderSettingsView: View {
    @Binding var readerDirection: ReaderDirection
    @Binding var hideStatusBar: Bool
    @Binding var keepScreenOn: Bool
    @Binding var zoomScale: ZoomScale
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reading Direction")) {
                    Picker("Direction", selection: $readerDirection) {
                        ForEach(ReaderDirection.allCases, id: \.self) { direction in
                            Text(direction.rawValue).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Zoom Options")) {
                    Picker("Default Zoom", selection: $zoomScale) {
                        ForEach(ZoomScale.allCases, id: \.self) { scale in
                            Text(scale.rawValue).tag(scale)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Interface")) {
                    Toggle("Hide Status Bar", isOn: $hideStatusBar)
                    Toggle("Keep Screen On", isOn: $keepScreenOn)
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Enums

enum ZoomScale: String, CaseIterable {
    case fitToScreen = "Fit Screen"
    case fitToWidth = "Fit Width"
    case originalSize = "Original"
}

class ChapterSelectorViewModel: ObservableObject {
    @Published var chapters: [Chapter] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedChapter: Chapter? = nil
    
    private let repository: MangaRepository = MockMangaRepository()
    private var cancellables = Set<AnyCancellable>()
    
    func loadChapters(mangaId: String) {
        isLoading = true
        errorMessage = nil
        
        repository.fetchMangaDetails(id: mangaId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] manga in
                    self?.chapters = manga.chapters.sorted(by: { $0.number > $1.number })
                }
            )
            .store(in: &cancellables)
    }
    
    func selectChapter(_ chapter: Chapter) {
        selectedChapter = chapter
        // Navigation will be handled by the parent view
    }
}

// MARK: - Update ViewModel for Navigation Support

class ChapterReaderViewModel: ObservableObject {
    @Published var pageUrls: [URL] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var nextChapter: Chapter? = nil
    @Published var previousChapter: Chapter? = nil
    
    private let repository: MangaRepository = MockMangaRepository()
    private var cancellables = Set<AnyCancellable>()
    private var manga: Manga?
    
    func loadChapterPages(mangaId: String, chapterId: String) {
        isLoading = true
        errorMessage = nil
        
        // Load chapter info and pages
        loadMangaDetails(mangaId: mangaId)
        
        repository.fetchChapterPages(mangaId: mangaId, chapterId: chapterId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] urls in
                    self?.pageUrls = urls
                }
            )
            .store(in: &cancellables)
    }
    
    func updateReadingProgress(mangaId: String, chapterId: String, page: Int) {
        repository.updateReadingProgress(mangaId: mangaId, chapterId: chapterId, page: page)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func loadMangaDetails(mangaId: String) {
        repository.fetchMangaDetails(id: mangaId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] manga in
                    self?.manga = manga
                    self?.updateChapterNavigation()
                }
            )
            .store(in: &cancellables)
    }
    
    func navigateToNextChapter() {
        guard let nextChapter = nextChapter else { return }
        loadChapterPages(mangaId: nextChapter.mangaId, chapterId: nextChapter.id)
    }
    
    func navigateToPreviousChapter() {
        guard let previousChapter = previousChapter else { return }
        loadChapterPages(mangaId: previousChapter.mangaId, chapterId: previousChapter.id)
    }
    
    private func updateChapterNavigation() {
        guard let manga = manga else { return }
        
        let sortedChapters = manga.chapters.sorted { $0.number < $1.number }
        
        if let currentChapterIndex = sortedChapters.firstIndex(where: { pageUrls.first?.absoluteString.contains($0.id) ?? false }) {
            // Set next chapter
            if currentChapterIndex < sortedChapters.count - 1 {
                nextChapter = sortedChapters[currentChapterIndex + 1]
            } else {
                nextChapter = nil
            }
            
            // Set previous chapter
            if currentChapterIndex > 0 {
                previousChapter = sortedChapters[currentChapterIndex - 1]
            } else {
                previousChapter = nil
            }
        }
    }
}

#Preview {
    NavigationView {
        ChapterReaderView(chapter: Chapter.sample)
    }
}
