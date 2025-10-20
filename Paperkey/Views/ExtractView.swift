//
//  ExtractView.swift
//  Paperkey
//
//  Created by helmholtz on 2025/10/13.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ExtractView: View {
    @ObservedObject var viewModel: ExtractViewModel
    @State private var showFileImporter = false
    @State private var sharePayload: SharePayload?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                formatPicker
                resultSection
            }
            .padding()
        }
        .navigationTitle("Extract")
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data, .utf8PlainText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let url):
                Task { await viewModel.importSecretKey(from: url[0]) }
            case .failure(let error):
                Task { @MainActor in
                    viewModel.setError(message: error.localizedDescription)
                }
            }
        }
        .alert(item: $viewModel.pendingAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items) {
                payload.cleanup()
                DispatchQueue.main.async {
                    sharePayload = nil
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Secret Key File")
                .font(.headline)
            Text(viewModel.fileName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if viewModel.isProcessing {
                ProgressView("Processing…")
            }
            Button {
                showFileImporter = true
            } label: {
                Label("Import Secret Key", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .disabled(viewModel.isProcessing)
        }
    }
    
    private var formatPicker: some View {
        Picker("Output Format", selection: $viewModel.selectedFormat) {
            ForEach(ExtractViewModel.OutputFormat.allCases) { format in
                Text(format.displayName).tag(format)
            }
        }
        .pickerStyle(.segmented)
        .disabled(viewModel.secretKeyData == nil || viewModel.isProcessing)
    }
    
    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.selectedFormat {
        case .base16:
            if let text = viewModel.extractedText {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Extracted Base16 Output")
                        .font(.headline)
                    ScrollView {
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                    }
                    .frame(minHeight: 120, maxHeight: 200)
                    Button {
                        guard let exportText = viewModel.extractedText else { return }
                        shareText(exportText, filename: "\(viewModel.suggestedExportName(for: .base16)).txt")
                    } label: {
                        Label("Share as TXT", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                }
            }
        case .binary:
            if let qr = viewModel.qrImage {
                VStack(alignment: .center, spacing: 12) {
                    Text("Raw Binary Output")
                        .font(.headline)
                    Picker("Error Correction", selection: $viewModel.correctionLevel) {
                        ForEach(ExtractViewModel.QRCorrectionLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    qr
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: 240, maxHeight: 240)
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    Text("Scan or print this QR code to recover your secret material.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button {
                            guard let data = viewModel.qrImageData else { return }
                            shareData(data, filename: "\(viewModel.suggestedExportName(for: .binary)).png")
                        } label: {
                            Label("Share as PNG", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonBorderShape(.roundedRectangle(radius: 12))
                        
                        Button {
                            guard let payload = viewModel.binaryPayload else { return }
                            shareData(payload, filename: "\(viewModel.suggestedRawBinaryExportName()).bin")
                        } label: {
                            Label("Share as BIN", systemImage: "arrow.down.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonBorderShape(.roundedRectangle(radius: 12))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private extension ExtractView {
    func shareText(_ text: String, filename: String) {
        guard let data = text.data(using: .utf8) else { return }
        shareData(data, filename: filename)
    }
    
    func shareData(_ data: Data, filename: String) {
        do {
            sharePayload = try SharePayload.makeFilePayload(data: data, filename: filename)
        } catch {
            viewModel.setError(message: error.localizedDescription)
        }
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
    let cleanup: () -> Void
    
    static func makeFilePayload(data: Data, filename: String) throws -> SharePayload {
        let tempDirectory = FileManager.default.temporaryDirectory
        let uniqueFilename = "\(UUID().uuidString)-\(filename)"
        let url = tempDirectory.appendingPathComponent(uniqueFilename)
        try data.write(to: url, options: .atomic)
        return SharePayload(items: [url]) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let completion: () -> Void
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ExtractView(viewModel: ExtractViewModel())
    }
}
