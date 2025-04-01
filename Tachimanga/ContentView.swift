//
//  ContentView.swift
//  Tachimanga
//
//  Created by ahmed on 02/04/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var networkStatus = NetworkStatus.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                MangaListView()
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            .tag(0)
            
            NavigationView {
                BrowseView()
            }
            .tabItem {
                Label("Browse", systemImage: "magnifyingglass")
            }
            .tag(1)
            
            NavigationView {
                ReadingHistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .tag(2)
            
            NavigationView {
                tabBasedOnNetworkStatus
            }
            .tabItem {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
            .tag(3)
            
            NavigationView {
                Text("Settings")
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(4)
        }
        .overlay(
            // Offline mode indicator
            Group {
                if !networkStatus.isConnected {
                    VStack {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("Offline Mode")
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .edgesIgnoringSafeArea(.top)
                }
            }
        )
    }
    
    @ViewBuilder
    private var tabBasedOnNetworkStatus: some View {
        if networkStatus.isConnected {
            DownloadsView()
        } else {
            OfflineLibraryView()
        }
    }
}

// Network status monitoring
class NetworkStatus: ObservableObject {
    static let shared = NetworkStatus()
    
    @Published var isConnected: Bool = true
    
    // In a real app, use NWPathMonitor to check network status
    // For demo, we'll simulate this
    init() {
        checkNetworkStatus()
    }
    
    func checkNetworkStatus() {
        isConnected = true
        
        // Simulate network checks
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.isConnected = Bool.random()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ServiceProvider.shared)
}
