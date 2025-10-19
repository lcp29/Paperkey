//
//  ContentView.swift
//  Paperkey
//
//  Created by helmholtz on 2025/10/13.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var extractViewModel = ExtractViewModel()
    @StateObject private var restoreViewModel = RestoreViewModel()
    @State private var selectedTab: Tab = .extract
    
    private enum Tab: Hashable {
        case extract
        case restore
        case about
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ExtractView(viewModel: extractViewModel)
            }
            .tabItem {
                Label("Extract", systemImage: "doc.badge.arrow.up")
            }
            .tag(Tab.extract)
            
            NavigationStack {
                RestoreView(viewModel: restoreViewModel)
            }
            .tabItem {
                Label("Restore", systemImage: "key.fill")
            }
            .tag(Tab.restore)
            
            NavigationStack {
                AboutView()
            }
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
            .tag(Tab.about)
        }
        .onOpenURL { url in
            handleIncoming(url: url)
        }
    }
    
    private func handleIncoming(url: URL) {
        let lowercased = url.lastPathComponent.lowercased()
        if lowercased.contains("pub") {
            selectedTab = .restore
            Task { await restoreViewModel.importPublicKey(from: url) }
        } else {
            selectedTab = .extract
            Task { await extractViewModel.importSecretKey(from: url) }
        }
    }
}

#Preview {
    ContentView()
}
