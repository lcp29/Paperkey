//
//  AboutView.swift
//  Paperkey
//
//  Created by helmholtz on 2025/10/13.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Paperkey"
    }
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "—"
    }
    
    private var iconName: String {
        colorScheme == .dark ? "icon-iOS-Dark-1024x1024" : "icon-iOS-Default-1024x1024"
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityHidden(true)
                    Text(appName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(String(localized: "Paperkey helps you protect your GPG secret keys with offline backups."))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                LabeledContent(String(localized: "Version"), value: appVersion)
            }
            
            Section(String(localized: "Community")) {
                Link(String(localized: "Source Code"), destination: URL(string: "https://github.com/lcp29/Paperkey")!)
                    .font(.body.weight(.medium))
                Link(String(localized: "Original paperkey library"), destination: URL(string: "https://github.com/dmshaw/paperkey")!)
                    .font(.body)
                Text(String(localized: "Distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            
            Section(String(localized: "Legal")) {
                LabeledContent(String(localized: "License"), value: String(localized: "GNU GPL v2"))
                NavigationLink {
                    LicenseView()
                } label: {
                    Label(String(localized: "View Full License"), systemImage: "doc.text.magnifyingglass")
                }
            }
        }
        .navigationTitle(String(localized: "About"))
        .listStyle(.insetGrouped)
    }
}

private struct LicenseView: View {
    private let licenseText = LicenseView.loadLicense()
    
    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(licenseText)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.leading)
                .padding()
        }
        .navigationTitle(String(localized: "License"))
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    private static func loadLicense() -> String {
        let notFound = String(localized: "License file not found.")
        let loadFailed = String(localized: "Unable to load license file.")
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") else {
            return notFound
        }
        do {
            return try String(contentsOf: url)
        } catch {
            return loadFailed
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

#Preview("License") {
    NavigationStack {
        LicenseView()
    }
}
