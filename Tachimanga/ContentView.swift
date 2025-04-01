//
//  ContentView.swift
//  Tachimanga
//
//  Created by ahmed on 02/04/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
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
                Text("Settings")
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(3)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ServiceProvider.shared)
}
