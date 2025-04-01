import SwiftUI

struct BrowseView: View {
    @StateObject private var viewModel = BrowseViewModel()
    @State private var sortOption: SortOption = .popularity
    @State private var showGenreFilter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search manga", text: $viewModel.searchQuery)
                    .foregroundColor(.primary)
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
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
            
            // Sorting and Filtering Controls
            HStack {
                Menu {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    showGenreFilter.toggle()
                }) {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                if viewModel.activeFilters.count > 0 {
                    Text("\(viewModel.activeFilters.count) filters")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Active Genre Filters
            if !viewModel.selectedGenres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.selectedGenres, id: \.self) { genre in
                            HStack(spacing: 4) {
                                Text(genre)
                                    .font(.caption)
                                
                                Button(action: {
                                    viewModel.toggleGenre(genre)
                                }) {
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
                        
                        Button(action: {
                            viewModel.clearGenreFilters()
                        }) {
                            Text("Clear All")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 4)
            }
            
            // Results
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.loadManga()
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            if !viewModel.searchQuery.isEmpty {
                                Text("Search Results")
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.top)
                            }
                            
                            MangaGridView(
                                title: viewModel.searchQuery.isEmpty ? "Browse Manga" : "",
                                manga: viewModel.displayedManga
                            )
                            
                            if viewModel.isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding()
                            }
                        }
                    }
                    // Replace .refreshable with a manual implementation
                    .background(RefreshControl(coordinator: viewModel.refreshControl))
                }
            }
        }
        .navigationTitle("Browse")
        .onAppear {
            viewModel.loadManga()
        }
        .onChange(of: sortOption) { _ in
            viewModel.sortManga(by: sortOption)
        }
        .sheet(isPresented: $showGenreFilter) {
            GenreFilterView(
                selectedGenres: $viewModel.selectedGenres,
                availableGenres: viewModel.availableGenres
            )
        }
    }
}

struct GenreFilterView: View {
    @Binding var selectedGenres: [String]
    let availableGenres: [String]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredGenres: [String] {
        if searchText.isEmpty {
            return availableGenres
        } else {
            return availableGenres.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search genres", text: $searchText)
                        .foregroundColor(.primary)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
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
                
                List {
                    ForEach(filteredGenres, id: \.self) { genre in
                        Button(action: {
                            toggleGenre(genre)
                        }) {
                            HStack {
                                Text(genre)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedGenres.contains(genre) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter by Genre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        selectedGenres = []
                    }
                }
            }
        }
    }
    
    private func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.removeAll { $0 == genre }
        } else {
            selectedGenres.append(genre)
        }
    }
}

enum SortOption: String, CaseIterable {
    case popularity
    case latestUpdates
    case alphabetical
    case status
    
    var displayName: String {
        switch self {
        case .popularity:
            return "Popularity"
        case .latestUpdates:
            return "Latest Updates"
        case .alphabetical:
            return "Alphabetical"
        case .status:
            return "Status"
        }
    }
}

#Preview {
    NavigationView {
        BrowseView()
    }
}
