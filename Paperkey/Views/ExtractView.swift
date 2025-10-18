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
                    }
                    .frame(minHeight: 200)
                }
            }
        case .binary:
            if let qr = viewModel.qrImage {
                VStack(alignment: .center, spacing: 12) {
                    Text("Binary Output QR")
                        .font(.headline)
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
