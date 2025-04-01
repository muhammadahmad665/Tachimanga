import SwiftUI
import Combine

struct AdvancedFilterView: View {
    // Filter bindings from parent view
    @Binding var selectedGenres: [String]
    @Binding var selectedStatus: [MangaStatus]
    @Binding var selectedLanguages: [String]
    @Binding var sortOption: MangaSortOption
    
    // Available filter options
    @State private var availableGenres: [String] = []
    @State private var availableLanguages: [String] = []
    @State private var searchText = ""
    
    // UI state
    @State private var isLoadingFilters = false
    @State private var activeTab = 0  // 0: Genres, 1: Status, 2: Languages, 3: Sort
    
    // Use StateObject for the view model to hold mutable state
    @StateObject private var viewModel = AdvancedFilterViewModel()
    
    @Environment(\.dismiss) private var dismiss
    
    // Add a public initializer with default parameter for repository
    init(
        selectedGenres: Binding<[String]>,
        selectedStatus: Binding<[MangaStatus]>,
        selectedLanguages: Binding<[String]>,
        sortOption: Binding<MangaSortOption>,
        repository: MangaRepository = ServiceProvider.shared.mangaRepository
    ) {
        self._selectedGenres = selectedGenres
        self._selectedStatus = selectedStatus
        self._selectedLanguages = selectedLanguages
        self._sortOption = sortOption
        // Set the repository in the viewModel after initialization
        let viewModel = AdvancedFilterViewModel()
        viewModel.repository = repository
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    filterTabButton("Genres", index: 0)
                    filterTabButton("Status", index: 1)
                    filterTabButton("Languages", index: 2)
                    filterTabButton("Sort", index: 3)
                }
                .padding(.top)
                
                Divider()
                
                if isLoadingFilters {
                    Spacer()
                    ProgressView("Loading filters...")
                    Spacer()
                } else {
                    tabContent
                }
                
                Divider()
                
                // Action buttons
                HStack {
                    Button("Reset All") {
                        resetFilters()
                    }
                    .foregroundColor(.red)
                    .padding()
                    
                    Spacer()
                    
                    Button("Apply Filters") {
                        dismiss()
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Advanced Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadAvailableFilters()
            }
        }
    }
    
    private var tabContent: some View {
        Group {
            switch activeTab {
            case 0:
                // Genres tab
                genresView
            case 1:
                // Status tab
                statusView
            case 2:
                // Languages tab
                languagesView
            case 3:
                // Sort tab
                sortOptionsView
            default:
                Text("Invalid tab")
            }
        }
    }
    
    private var genresView: some View {
        VStack {
            // Search for genres
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search genres", text: $searchText)
                    .foregroundColor(.primary)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top)
            
            // Selected genres chips
            if !selectedGenres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedGenres, id: \.self) { genre in
                            GenreChip(name: genre) {
                                withAnimation {
                                    selectedGenres.removeAll { $0 == genre }
                                }
                            }
                        }
                        
                        if selectedGenres.count > 1 {
                            Button("Clear All") {
                                withAnimation {
                                    selectedGenres = []
                                }
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            
            // Genre grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 170))], spacing: 12) {
                    let filteredGenres = searchText.isEmpty ? 
                        availableGenres : 
                        availableGenres.filter { $0.localizedCaseInsensitiveContains(searchText) }
                    
                    ForEach(filteredGenres, id: \.self) { genre in
                        GenreToggleButton(
                            genre: genre,
                            isSelected: selectedGenres.contains(genre),
                            action: {
                                toggleGenre(genre)
                            }
                        )
                    }
                }
                .padding()
                .animation(.default, value: searchText)
            }
        }
    }
    
    private var statusView: some View {
        List {
            ForEach(MangaStatus.allCases, id: \.self) { status in
                Button {
                    toggleStatus(status)
                } label: {
                    HStack {
                        Text(status.rawValue)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedStatus.contains(status) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
    }
    
    private var languagesView: some View {
        List {
            ForEach(availableLanguages, id: \.self) { language in
                Button {
                    toggleLanguage(language)
                } label: {
                    HStack {
                        Text(language)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedLanguages.contains(language) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
    }
    
    private var sortOptionsView: some View {
        List {
            ForEach(MangaSortOption.allCases, id: \.self) { option in
                Button {
                    sortOption = option
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(option.rawValue)
                                .foregroundColor(.primary)
                            
                            Text(getSortDescription(for: option))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if sortOption == option {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func filterTabButton(_ title: String, index: Int) -> some View {
        Button(action: {
            withAnimation {
                activeTab = index
            }
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .foregroundColor(activeTab == index ? .primary : .secondary)
                    .fontWeight(activeTab == index ? .semibold : .regular)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Active indicator
                Rectangle()
                    .fill(activeTab == index ? Color.blue : Color.clear)
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func loadAvailableFilters() {
        isLoadingFilters = true
        
        viewModel.repository.getAvailableFilters()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoadingFilters = false
                    if case .failure(let error) = completion {
                        print("Failed to load filters: \(error)")
                    }
                },
                receiveValue: { filterOptions in
                    availableGenres = filterOptions.genres
                    availableLanguages = filterOptions.languages
                }
            )
            .store(in: &viewModel.cancellables)
    }
    
    private func toggleGenre(_ genre: String) {
        withAnimation {
            if selectedGenres.contains(genre) {
                selectedGenres.removeAll { $0 == genre }
            } else {
                selectedGenres.append(genre)
            }
        }
    }
    
    private func toggleStatus(_ status: MangaStatus) {
        withAnimation {
            if selectedStatus.contains(status) {
                selectedStatus.removeAll { $0 == status }
            } else {
                selectedStatus.append(status)
            }
        }
    }
    
    private func toggleLanguage(_ language: String) {
        withAnimation {
            if selectedLanguages.contains(language) {
                selectedLanguages.removeAll { $0 == language }
            } else {
                selectedLanguages.append(language)
            }
        }
    }
    
    private func resetFilters() {
        withAnimation {
            selectedGenres.removeAll()
            selectedStatus.removeAll()
            selectedLanguages.removeAll()
            sortOption = .popularity
        }
    }
    
    private func getSortDescription(for option: MangaSortOption) -> String {
        switch option {
        case .alphabetical:
            return "Sort titles from A to Z"
        case .popularity:
            return "Sort by most popular titles"
        case .releaseDate:
            return "Sort by newest releases first"
        case .latestUpdate:
            return "Sort by most recently updated"
        }
    }
}

// View model class to hold mutable state
class AdvancedFilterViewModel: ObservableObject {
    var repository: MangaRepository = ServiceProvider.shared.mangaRepository
    var cancellables = Set<AnyCancellable>()
}

// MARK: - Supporting Views

struct GenreToggleButton: View {
    let genre: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(genre)
                .font(.caption)
                .fontWeight(isSelected ? .medium : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GenreChip: View {
    let name: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

#Preview {
    AdvancedFilterView(
        selectedGenres: .constant(["Action", "Adventure"]),
        selectedStatus: .constant([.ongoing]),
        selectedLanguages: .constant(["English"]),
        sortOption: .constant(.popularity)
    )
}
