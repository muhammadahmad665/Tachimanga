import SwiftUI

struct BrowseView: View {
    @StateObject private var viewModel = BrowseViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top search and filter toolbar
            HStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search manga", text: $viewModel.searchQuery)
                        .foregroundColor(.primary)
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.searchQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Source selection button
                Button(action: {
                    viewModel.showSourceSelector = true
                }) {
                    Label("Source", systemImage: "book.fill")
                        .labelStyle(.iconOnly)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                // Filter button
                Button(action: {
                    viewModel.showAdvancedFilters = true
                }) {
                    ZStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        if viewModel.activeFilterCount > 0 {
                            Text("\(viewModel.activeFilterCount)")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .offset(x: 10, y: -10)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Current Source Indicator
            if let source = viewModel.currentSource {
                HStack(spacing: 4) {
                    Image(systemName: source.icon)
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Source: \(source.name)")
                        .foregroundColor(.primary)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    // Show active filters if any
                    if viewModel.activeFilterCount > 0 {
                        HStack {
                            Text("\(viewModel.activeFilterCount) filters active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                viewModel.clearFilters()
                                viewModel.refreshData()
                            }) {
                                Text("Clear")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.5))
            }
            
            // Selected Genre Pills (only show if not searching)
            if viewModel.searchQuery.isEmpty && !viewModel.selectedGenres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.selectedGenres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
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
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), spacing: 16)],
                            spacing: 20
                        ) {
                            ForEach(viewModel.displayedManga) { manga in
                                NavigationLink(destination: MangaDetailView(mangaId: manga.id)) {
                                    MangaGridItem(manga: manga)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onAppear {
                                    // If this is one of the last items, load more
                                    if manga.id == viewModel.displayedManga.last?.id {
                                        viewModel.loadMoreManga()
                                    }
                                }
                            }
                        }
                        .padding()
                        
                        // Loading indicator at the bottom when loading more data
                        if viewModel.isLoadingMore {
                            ProgressView("Loading more...")
                                .padding()
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Empty state if no results
                        if viewModel.displayedManga.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 20) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                    .padding()
                                
                                if !viewModel.searchQuery.isEmpty {
                                    Text("No results found for '\(viewModel.searchQuery)'")
                                        .font(.headline)
                                        .multilineTextAlignment(.center)
                                } else if viewModel.activeFilterCount > 0 {
                                    Text("No manga found with current filters")
                                        .font(.headline)
                                    
                                    Button(action: {
                                        viewModel.clearFilters()
                                        viewModel.refreshData()
                                    }) {
                                        Text("Clear Filters")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                } else {
                                    Text("No manga available")
                                        .font(.headline)
                                }
                            }
                            .padding(.top, 50)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .background(RefreshControl(coordinator: viewModel.refreshControl))
                }
            }
        }
        .navigationTitle("Browse")
        .onAppear {
            viewModel.loadManga()
        }
        .sheet(isPresented: $viewModel.showSourceSelector) {
            SourceSelectorView { source in
                viewModel.handleSourceChanged(source)
            }
        }
        .sheet(isPresented: $viewModel.showAdvancedFilters) {
            AdvancedFilterView(
                selectedGenres: $viewModel.selectedGenres,
                selectedStatus: $viewModel.selectedStatus,
                selectedLanguages: $viewModel.selectedLanguages,
                sortOption: $viewModel.sortOption
            )
            .onDisappear {
                // Reload data when filters changed
                viewModel.refreshData()
            }
        }
    }
}

#Preview {
    NavigationView {
        BrowseView()
    }
}
