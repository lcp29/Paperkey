//
//  ExtractView.swift
//  Paperkey
//
//  Created by helmholtz on 2025/10/13.
//

import SwiftUI
import UniformTypeIdentifiers

struct ExtractView: View {
    @ObservedObject var viewModel: ExtractViewModel
    @State private var showFileImporter = false
    @State private var isExporting = false
    @State private var exportDocument = ExtractExportDocument.placeholder
    @State private var exportFilename = "paperkey-export"
    
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Import Secret Key", systemImage: "square.and.arrow.down")
                }
            }
        }
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
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportDocument.contentType,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
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
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Secret Key File")
                .font(.headline)
            Group {
                Text(viewModel.fileName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let updated = viewModel.lastUpdated {
                    Text("Processed \(updated, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
            }
            .disabled(viewModel.isProcessing)
        }
    }
    
    private var formatPicker: some View {
        Picker("Output Format", selection: $viewModel.selectedFormat) {
            ForEach(ExtractViewModel.OutputFormat.allCases) { format in
                Text(format.rawValue).tag(format)
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
                        exportDocument = .text(exportText)
                        exportFilename = "\(viewModel.suggestedExportName(for: .base16)).txt"
                        isExporting = true
                    } label: {
                        Label("Export as TXT", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        case .binary:
            if let qr = viewModel.qrImage {
                VStack(alignment: .center, spacing: 12) {
                    Text("Binary Output QR")
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
                        .frame(maxWidth: 280, maxHeight: 280)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Scan or print this QR code to recover your secret material.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        guard let data = viewModel.qrImageData else { return }
                        exportDocument = .png(data)
                        exportFilename = "\(viewModel.suggestedExportName(for: .binary)).png"
                        isExporting = true
                    } label: {
                        Label("Export as PNG", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExtractView(viewModel: ExtractViewModel())
    }
}

private struct ExtractExportDocument: FileDocument {
    enum Payload {
        case text(String)
        case png(Data)
        case empty
    }
    
    static var readableContentTypes: [UTType] { [] }
    static var writableContentTypes: [UTType] { [.plainText, .png] }
    
    var payload: Payload
    
    var contentType: UTType {
        switch payload {
        case .text:
            return .plainText
        case .png:
            return .png
        case .empty:
            return .plainText
        }
    }
    
    static var placeholder: ExtractExportDocument {
        ExtractExportDocument(payload: .empty)
    }
    
    init(payload: Payload) {
        self.payload = payload
    }
    
    init(configuration: ReadConfiguration) throws {
        self.payload = .empty
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        switch payload {
        case .text(let string):
            return FileWrapper(regularFileWithContents: Data(string.utf8))
        case .png(let data):
            return FileWrapper(regularFileWithContents: data)
        case .empty:
            return FileWrapper(regularFileWithContents: Data())
        }
    }
}

private extension ExtractExportDocument {
    static func text(_ string: String) -> ExtractExportDocument {
        ExtractExportDocument(payload: .text(string))
    }
    
    static func png(_ data: Data) -> ExtractExportDocument {
        ExtractExportDocument(payload: .png(data))
    }
}
