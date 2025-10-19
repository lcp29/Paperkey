//
//  RestoreViewModel.swift
//  Paperkey
//
//  Created by helmholtz on 2025/10/13.
//

import Foundation
import PaperkeyKit
internal import Combine

@MainActor
final class RestoreViewModel: ObservableObject {
    @Published private(set) var publicKeyURL: URL?
    @Published private(set) var publicKeyData: Data?
    @Published private(set) var publicKeyName: String = String(localized: "No file selected")
    @Published var secretInput: String = ""
    @Published private(set) var secretFileName: String = String(localized: "No secret file selected")
    @Published private(set) var secretFileContents: String?
    @Published private(set) var scannedBinaryPayload: Data?
    @Published private(set) var hasImportedSecret = false
    @Published var ignoreCRCError = false
    @Published private(set) var restoredKeyData: Data?
    @Published private(set) var restoredFileName: String = "restored-secret.gpg"
    @Published private(set) var successMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isProcessing = false
    @Published private(set) var lastRestored: Date?
    
    var secretStatusSystemImage: String {
        if scannedBinaryPayload != nil {
            return "externaldrive.fill"
        }
        return hasImportedSecret ? "doc.text.fill" : "doc.text"
    }
    
    func handleManualSecretInputChange(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if scannedBinaryPayload != nil {
            scannedBinaryPayload = nil
            if secretFileContents == nil {
                hasImportedSecret = false
                secretFileName = String(localized: "No secret file selected")
            } else {
                hasImportedSecret = true
            }
        }
    }
    
    func importPublicKey(from url: URL) async {
        errorMessage = nil
        do {
            let data = try readData(from: url)
            publicKeyData = data
            publicKeyURL = url
            publicKeyName = url.lastPathComponent
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func applyScannedPayload(_ payload: QRScannerView.Payload) {
        if let rawString = payload.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawString.isEmpty,
           isRecognizedTextPayload(rawString) {
            clearImportedSecret()
            secretInput = rawString
            successMessage = String(localized: "QR payload received.")
            return
        }
        
        scannedBinaryPayload = payload.rawData
        secretFileContents = nil
        secretFileName = String(localized: "Scanned QR payload")
        hasImportedSecret = true
        secretInput.removeAll()
        successMessage = String(localized: "QR payload received.")
    }
    
    func setError(message: String) {
        errorMessage = message
    }
    
    func restoreSecretKey() async {
        guard let pubring = publicKeyData else {
            errorMessage = String(localized: "Import a matching public key before restoring.")
            return
        }
        
        let textSource: String?
        if let contents = secretFileContents, !contents.isEmpty {
            textSource = contents
        } else {
            let trimmedInput = secretInput.trimmingCharacters(in: .whitespacesAndNewlines)
            textSource = trimmedInput.isEmpty ? nil : trimmedInput
        }
        
        if textSource == nil && scannedBinaryPayload == nil {
            errorMessage = String(localized: "Import the secret text file, scan, or paste the secret data before restoring.")
            return
        }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let prepared: (data: Data, inputType: PaperkeyKit.DataType)
            if let text = textSource {
                prepared = try prepareSecrets(from: text)
            } else if let binaryPayload = scannedBinaryPayload {
                prepared = (binaryPayload, .RAW)
            } else {
                throw RestorationError.unrecognizedSecrets
            }
            let ignoreCRC = ignoreCRCError
            let restored = try await Task.detached(priority: .userInitiated) {
                guard let data = PaperkeyKit.restore(
                    pubring: pubring,
                    secrets: prepared.data,
                    inputType: prepared.inputType,
                    ignoreCRCError: ignoreCRC
                ) else {
                    throw RestorationError.restoreFailed
                }
                return data
            }.value
            
            restoredKeyData = restored
            restoredFileName = makeFileName()
            successMessage = String(localized: "Secret key restored (\(restored.count) bytes).")
            lastRestored = Date()
        } catch {
            errorMessage = error.localizedDescription
            restoredKeyData = nil
        }
        
        isProcessing = false
    }
    
    func importSecretFile(from url: URL) async {
        errorMessage = nil
        do {
            let data = try readData(from: url)
            guard let contents = String(data: data, encoding: .utf8) else {
                throw RestorationError.encodingFailure
            }
            let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw RestorationError.unrecognizedSecrets
            }
            secretFileContents = trimmed
            secretFileName = url.lastPathComponent
            hasImportedSecret = true
            scannedBinaryPayload = nil
        } catch {
            secretFileContents = nil
            secretFileName = String(localized: "No secret file selected")
            hasImportedSecret = false
            scannedBinaryPayload = nil
            errorMessage = error.localizedDescription
        }
    }

    func importSecretBinary(from url: URL) async {
        errorMessage = nil
        do {
            let data = try readData(from: url)
            guard !data.isEmpty else {
                throw RestorationError.unrecognizedSecrets
            }
            scannedBinaryPayload = data
            secretFileContents = nil
            secretInput.removeAll()
            secretFileName = url.lastPathComponent
            hasImportedSecret = true
        } catch {
            scannedBinaryPayload = nil
            if secretFileContents == nil {
                secretFileName = String(localized: "No secret file selected")
                hasImportedSecret = false
            }
            errorMessage = error.localizedDescription
        }
    }
    
    func clearImportedSecret() {
        secretFileContents = nil
        secretFileName = String(localized: "No secret file selected")
        scannedBinaryPayload = nil
        hasImportedSecret = false
    }
    
    private func prepareSecrets(from string: String) throws -> (data: Data, inputType: PaperkeyKit.DataType) {
        let compact = string.replacingOccurrences(of: "\r\n", with: "\n")
        let stripped = compact.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let rawData = Data(base64Encoded: stripped, options: [.ignoreUnknownCharacters]), !rawData.isEmpty {
            return (rawData, .RAW)
        }
        
        if isStructuredBase16Payload(stripped) || isPlainBase16Payload(stripped) {
            guard let data = stripped.data(using: .utf8) else {
                throw RestorationError.encodingFailure
            }
            return (data, .BASE16)
        }
        
        throw RestorationError.unrecognizedSecrets
    }
    
    private func isPlainBase16Payload(_ string: String) -> Bool {
        let hexDigits = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        var hasHexDigit = false
        
        for scalar in string.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }
            guard hexDigits.contains(scalar) else {
                return false
            }
            hasHexDigit = true
        }
        
        return hasHexDigit
    }
    
    private func isStructuredBase16Payload(_ string: String) -> Bool {
        let hexDigits = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        var hasDataLine = false
        var isValid = true
        
        string.enumerateLines { line, stop in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                return
            }
            
            if trimmedLine.hasPrefix("#") {
                return
            }
            
            guard let colonIndex = trimmedLine.firstIndex(of: ":") else {
                isValid = false
                stop = true
                return
            }
            
            let lineNumberPart = trimmedLine[..<colonIndex].trimmingCharacters(in: .whitespaces)
            guard !lineNumberPart.isEmpty, lineNumberPart.allSatisfy({ $0.isNumber }) else {
                isValid = false
                stop = true
                return
            }
            
            let payloadStart = trimmedLine.index(after: colonIndex)
            let payloadPart = trimmedLine[payloadStart...].trimmingCharacters(in: .whitespaces)
            guard !payloadPart.isEmpty else {
                isValid = false
                stop = true
                return
            }
            
            let tokens = payloadPart.split(whereSeparator: { $0.isWhitespace })
            guard tokens.count >= 1 else {
                isValid = false
                stop = true
                return
            }
            
            for token in tokens.dropLast() {
                guard token.count == 2,
                      token.unicodeScalars.allSatisfy({ hexDigits.contains($0) }) else {
                    isValid = false
                    stop = true
                    return
                }
            }
            
            let checksum = tokens.last!
            guard checksum.count >= 2,
                  checksum.unicodeScalars.allSatisfy({ hexDigits.contains($0) }) else {
                isValid = false
                stop = true
                return
            }
            
            hasDataLine = true
        }
        
        return isValid && hasDataLine
    }
    
    private func isRecognizedTextPayload(_ string: String) -> Bool {
        if Data(base64Encoded: string, options: [.ignoreUnknownCharacters]) != nil {
            return true
        }
        
        if isStructuredBase16Payload(string) || isPlainBase16Payload(string) {
            return true
        }
        
        return false
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
}

extension RestoreViewModel {
    private func makeFileName() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date())
        return "restored-secret-\(timestamp).gpg"
    }
    
    enum RestorationError: LocalizedError {
        case restoreFailed
        case encodingFailure
        case unrecognizedSecrets
        
        var errorDescription: String? {
            switch self {
            case .restoreFailed:
                return String(localized: "Could not rebuild the secret key with the provided data.")
            case .encodingFailure:
                return String(localized: "The provided secret text is not valid UTF-8.")
            case .unrecognizedSecrets:
                return String(localized: "Secret data was not recognized as base16 text or binary payload.")
            }
        }
    }
}
