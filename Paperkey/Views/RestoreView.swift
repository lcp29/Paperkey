//
//  RestoreView.swift
//  Paperkey
//
//  Created by helmholtz on 2025/10/13.
//

import SwiftUI
import UniformTypeIdentifiers

struct RestoreView: View {
    @ObservedObject var viewModel: RestoreViewModel
    @State private var showScanner = false
    @State private var showShareSheet = false
    @State private var manualSecretExpanded = false
    @State private var showImporter = false
    @State private var importerDestination: ImportDestination?
    @State private var importerAllowedTypes: [UTType] = [.data, .utf8PlainText, .plainText, .text]
    
    private enum ImportDestination {
        case publicKey
        case secretText
        case secretBinary
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                publicKeySection
                secretInputSection
                optionsSection
                statusSection
                if let data = viewModel.restoredKeyData {
                    shareSection(for: data)
                }
            }
            .padding()
        }
        .navigationTitle("Restore")
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: importerAllowedTypes,
            allowsMultipleSelection: false
        ) { result in
            guard let destination = importerDestination else { return }
            switch result {
            case .success(let url):
                switch destination {
                case .publicKey:
                    Task { await viewModel.importPublicKey(from: url[0]) }
                case .secretText:
                    Task { await viewModel.importSecretFile(from: url[0]) }
                case .secretBinary:
                    Task { await viewModel.importSecretBinary(from: url[0]) }
                }
            case .failure(let error):
                Task { @MainActor in
                    viewModel.setError(message: error.localizedDescription)
                }
            }
            importerDestination = nil
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = viewModel.restoredKeyData {
                ShareSheet(activityItems: [ShareableItem(data: data, fileName: viewModel.restoredFileName)])
            }
        }
        .sheet(isPresented: $showScanner) {
            NavigationStack {
                QRScannerView { result in
                    switch result {
                    case .success(let payload):
                        Task { @MainActor in
                            viewModel.applyScannedPayload(payload)
                            showScanner = false
                        }
                    case .failure(let error):
                        Task { @MainActor in
                            viewModel.setError(message: error.localizedDescription)
                            showScanner = false
                        }
                    }
                }
                .navigationTitle("Scan Secret QR")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showScanner = false }
                    }
                }
            }
        }
    }
    
    private var publicKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Public Key")
                .font(.headline)
            Text(viewModel.publicKeyName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                importerDestination = .publicKey
                importerAllowedTypes = [.data]
                showImporter = true
            } label: {
                Label("Import Public Key", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .disabled(viewModel.isProcessing)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var secretInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Secret Data")
                .font(.headline)
            secretFileStatus
            HStack(spacing: 8) {
                Button {
                    importerDestination = .secretText
                    importerAllowedTypes = [.utf8PlainText, .plainText, .text]
                    showImporter = true
                } label: {
                    VStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Import Secret Base16 Text")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .font(.headline)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .disabled(viewModel.isProcessing)
                Button {
                    importerDestination = .secretBinary
                    importerAllowedTypes = [.data]
                    showImporter = true
                } label: {
                    VStack {
                        Image(systemName: "tray.and.arrow.down")
                        Text("Import Secret BIN")
                    }.frame(maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .font(.headline)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .disabled(viewModel.isProcessing)
                Button {
                    showScanner = true
                } label: {
                    VStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Scan QR")
                    }.frame(maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .font(.headline)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .disabled(viewModel.isProcessing)
            }
            DisclosureGroup(isExpanded: $manualSecretExpanded) {
                TextEditor(text: $viewModel.secretInput)
                    .frame(minHeight: 120, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )
                    .disabled(viewModel.isProcessing)
                    .accessibilityHint("Manual backup input for secret data.")
                HStack {
                    Button {
                        viewModel.secretInput.removeAll()
                    } label: {
                        Label("Clear Text", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.secretInput.isEmpty || viewModel.isProcessing)
                }
            } label: {
                Text("Paste secret manually")
            }
        }
        .onAppear {
            manualSecretExpanded = !viewModel.secretInput.isEmpty
        }
        .onChange(of: viewModel.secretInput) { newValue in
            manualSecretExpanded = !newValue.isEmpty
            viewModel.handleManualSecretInputChange(newValue)
        }
    }
    
    private var secretFileStatus: some View {
        Group {
            if viewModel.hasImportedSecret {
                HStack {
                    Label(viewModel.secretFileName, systemImage: viewModel.secretStatusSystemImage)
                        .font(.subheadline)
                    Button(role: .destructive) {
                        viewModel.clearImportedSecret()
                    } label: {
                        Text("Remove")
                    }
                    .disabled(viewModel.isProcessing)
                }
            } else {
                Label("No secret file selected", systemImage: viewModel.secretStatusSystemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Ignore CRC Errors", isOn: $viewModel.ignoreCRCError)
                .toggleStyle(.switch)
            Button {
                Task { await viewModel.restoreSecretKey() }
            } label: {
                Label("Restore Secret Key", systemImage: "arrow.clockwise.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .disabled(viewModel.isProcessing)
        }
    }
    
    @ViewBuilder
    private var statusSection: some View {
        if viewModel.isProcessing {
            ProgressView("Restoring…")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let success = viewModel.successMessage {
            Label(success, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
        if let restoredAt = viewModel.lastRestored {
            Text("Last restored \(restoredAt, style: .relative)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func shareSection(for data: Data) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export")
                .font(.headline)
            Button {
                showShareSheet = true
            } label: {
                Label("Share Restored Key", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
    }
}

final class ShareableItem: NSObject, UIActivityItemSource {
    private let data: Data
    private let fileName: String
    private var temporaryFileURL: URL?
    private var containerURL: URL?
    
    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL() ?? data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        fileURL() ?? data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        fileName
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        if let extensionIdentifier = temporaryFileURL?.pathExtension,
           !extensionIdentifier.isEmpty,
           let type = UTType(filenameExtension: extensionIdentifier)?.identifier {
            return type
        }
        return UTType.data.identifier
    }
    
    private func fileURL() -> URL? {
        if let url = temporaryFileURL {
            return url
        }
        
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent("PaperkeyShare-\(UUID().uuidString)", isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let targetURL = directory.appendingPathComponent(fileName)
            try data.write(to: targetURL, options: [.atomic])
            temporaryFileURL = targetURL
            containerURL = directory
            return targetURL
        } catch {
            return nil
        }
    }
    
    deinit {
        if let containerURL {
            try? FileManager.default.removeItem(at: containerURL)
        } else if let temporaryFileURL {
            try? FileManager.default.removeItem(at: temporaryFileURL)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        RestoreView(viewModel: RestoreViewModel())
    }
}
