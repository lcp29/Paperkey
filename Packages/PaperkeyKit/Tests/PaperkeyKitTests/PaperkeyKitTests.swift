import Testing
import Foundation
@testable import CPaperkey
@testable import PaperkeyKit

@Suite("Paperkey Roundtrip Tests")
struct PaperkeyKitTests {
    
    @Test("Roundtrip test for RSA key type")
    func rsaRoundtrip() async throws {
        try await performRoundtripTest(keyType: "rsa")
    }
    
    @Test("Roundtrip test for DSA+ElGamal key type")
    func dsaelgRoundtrip() async throws {
        try await performRoundtripTest(keyType: "dsaelg")
    }
    
    @Test("Roundtrip test for ECC key type")
    func eccRoundtrip() async throws {
        try await performRoundtripTest(keyType: "ecc")
    }
    
    @Test("Roundtrip test for EdDSA key type")
    func eddsaRoundtrip() async throws {
        try await performRoundtripTest(keyType: "eddsa")
    }
    
    private func performRoundtripTest(keyType: String) async throws {
        // Load test key files from the bundle resources
        let bundle = Bundle.module
        
        // The test files are in the "checks" subdirectory of the bundle
        guard let checksURL = bundle.url(forResource: "checks", withExtension: nil) else {
            throw TestError.directoryNotFound("checks")
        }
        
        let secURL = checksURL.appendingPathComponent("papertest-\(keyType).sec")
        let pubURL = checksURL.appendingPathComponent("papertest-\(keyType).pub")
        
        guard FileManager.default.fileExists(atPath: secURL.path) else {
            throw TestError.fileNotFound("papertest-\(keyType).sec at \(secURL.path)")
        }
        
        guard FileManager.default.fileExists(atPath: pubURL.path) else {
            throw TestError.fileNotFound("papertest-\(keyType).pub at \(pubURL.path)")
        }
        
        let secData = try Data(contentsOf: secURL)
        let pubData = try Data(contentsOf: pubURL)
        
        // Test raw binary format roundtrip
        let extractedRaw = try #require(PaperkeyKit.extract(input: secData, outputType: .RAW, outputWidth: 78))
        let restoredRaw = try #require(PaperkeyKit.restore(pubring: pubData, secrets: extractedRaw, inputType: .RAW, ignoreCRCError: false))
        
        #expect(restoredRaw == secData, "Raw binary roundtrip failed for \(keyType) key")
        
        // Test base16 text format roundtrip
        let extractedBase16 = try #require(PaperkeyKit.extract(input: secData, outputType: .BASE16, outputWidth: 78))
        let restoredBase16 = try #require(PaperkeyKit.restore(pubring: pubData, secrets: extractedBase16, inputType: .BASE16, ignoreCRCError: false))
        
        #expect(restoredBase16 == secData, "Base16 roundtrip failed for \(keyType) key")
    }
    
    enum TestError: Error, CustomDebugStringConvertible {
        case fileNotFound(String)
        case directoryNotFound(String)
        
        var debugDescription: String {
            switch self {
            case .fileNotFound(let filename):
                return "Test data file not found: \(filename)"
            case .directoryNotFound(let dirname):
                return "Test data directory not found: \(dirname)"
            }
        }
    }
}
