//
//  ExtractViewModel.swift
//  Paperkey
//
//  Created by helmholtz on 2025/10/13.
//

import Foundation
import SwiftUI
import UIKit
import PaperkeyKit
import CoreImage.CIFilterBuiltins
internal import Combine

@MainActor
final class ExtractViewModel: ObservableObject {
    enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
        case binary = "Binary (QR)"
        case base16 = "Base16 (Text)"
        
        var id: String { rawValue }
        
        var kitType: PaperkeyKit.DataType {
            switch self {
            case .binary: return .RAW
            case .base16: return .BASE16
            }
        }
    }
    
    @Published var selectedFormat: OutputFormat = .binary {
        didSet {
            guard let currentSecret = secretKeyData else { return }
            Task { await runExtraction(on: currentSecret) }
        }
    }
    @Published private(set) var secretKeyURL: URL?
    @Published private(set) var secretKeyData: Data?
    @Published private(set) var extractedText: String?
    @Published private(set) var qrImage: Image?
    @Published private(set) var qrImageData: Data?
    @Published var correctionLevel: QRCorrectionLevel = .medium {
        didSet {
            guard selectedFormat == .binary, let currentSecret = secretKeyData else { return }
            Task { await runExtraction(on: currentSecret) }
        }
    }
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var fileName: String = "No file selected"
    @Published private(set) var lastUpdated: Date?
    
    private let outputWidth: UInt = 78
    
    func importSecretKey(from url: URL) async {
        errorMessage = nil
        do {
            let data = try readData(from: url)
            secretKeyURL = url
            secretKeyData = data
            fileName = url.lastPathComponent
            await runExtraction(on: data)
        } catch {
            errorMessage = error.localizedDescription
            secretKeyURL = nil
            secretKeyData = nil
            extractedText = nil
            qrImage = nil
            qrImageData = nil
        }
    }
    
    func setError(message: String) {
        errorMessage = message
    }
    
    private func runExtraction(on data: Data) async {
        isProcessing = true
        do {
            let format = selectedFormat
            let correction = correctionLevel
            let payload = try await Task.detached(priority: .userInitiated) { 
                () -> ExtractionPayload in
                guard let result = await PaperkeyKit.extract(input: data, outputType: format.kitType, outputWidth: self.outputWidth) else {
                    throw ExtractionError.extractionFailed
                }
                
                switch format {
                case .base16:
                    guard let text = String(data: result, encoding: .utf8) else {
                        throw ExtractionError.encodingFailed
                    }
                    return .text(text)
                case .binary:
                    return .qrPayload(result)
                }
            }.value
            
            switch payload {
            case .text(let text):
                extractedText = text
                qrImage = nil
                qrImageData = nil
            case .qrPayload(let data):
                guard let image = Self.makeQRCode(from: data, correctionLevel: correction) else {
                    throw ExtractionError.qrGenerationFailed
                }
                extractedText = nil
                qrImage = Image(uiImage: image)
                guard let pngData = image.pngData() else {
                    throw ExtractionError.qrGenerationFailed
                }
                qrImageData = pngData
            }
            
            errorMessage = nil
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
            extractedText = nil
            qrImage = nil
            qrImageData = nil
        }
        isProcessing = false
    }
    
    private func readData(from url: URL) throws -> Data {
        var didAccess = false
        if url.startAccessingSecurityScopedResource() {
            didAccess = true
        }
        
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return try Data(contentsOf: url)
    }
    
    private static func makeQRCode(from data: Data, correctionLevel: QRCorrectionLevel) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correctionLevel.ciValue
        
        guard let ciImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

extension ExtractViewModel {
    private enum ExtractionPayload: Sendable {
        case text(String)
        case qrPayload(Data)
    }
    
    enum ExtractionError: LocalizedError {
        case extractionFailed
        case encodingFailed
        case qrGenerationFailed
        
        var errorDescription: String? {
            switch self {
            case .extractionFailed:
                return "Failed to extract secret data from the supplied key."
            case .encodingFailed:
                return "The extracted data could not be converted to text."
            case .qrGenerationFailed:
                return "Could not create a QR code for the extracted data."
            }
        }
    }
    
    func suggestedExportName(for format: OutputFormat) -> String {
        let base = secretKeyURL?
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: " ", with: "-")
            .lowercased() ?? "paperkey"
        switch format {
        case .binary:
            return "\(base)-qr"
        case .base16:
            return "\(base)-secret"
        }
    }
}

extension ExtractViewModel {
    enum QRCorrectionLevel: String, CaseIterable, Identifiable {
        case low = "L (7%)"
        case medium = "M (15%)"
        case quartile = "Q (25%)"
        case high = "H (30%)"
        
        var id: String { rawValue }
        
        var ciValue: String {
            switch self {
            case .low: return "L"
            case .medium: return "M"
            case .quartile: return "Q"
            case .high: return "H"
            }
        }
    }
}
