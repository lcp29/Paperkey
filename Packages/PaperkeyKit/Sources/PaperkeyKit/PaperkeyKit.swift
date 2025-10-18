//
//  PaperkeyKit.swift
//  PaperkeyKit
//
//  Created by helmholtz on 2025/10/13.
//

import Darwin
import Foundation
import CPaperkey

public class PaperkeyKit {
    public enum DataType {
        /// Automatically detect the data type
        case AUTO
        /// Raw binary data
        case RAW
        /// Base16 (hexadecimal) encoded text
        case BASE16
    }
    
    /// Extracts secret data from an OpenPGP secret key file.
    ///
    /// This function extracts the secret key material from a GPG secret key file and outputs it in a specified format.
    /// The extracted data can be printed on paper for backup purposes.
    ///
    /// - Parameters:
    ///   - input: The OpenPGP secret key data as a Data object
    ///   - outputType: The format for the output data (AUTO, RAW, or BASE16)
    ///   - outputWidth: The number of characters per line for the output (typically 78 for standard formatting)
    /// - Returns: The extracted secret data in the specified format, or nil if extraction fails
    ///
    /// # Example:
    /// ```swift
    /// let secretKeyData = Data(...) // Load your GPG secret key
    /// if let extracted = Paperkey.extract(input: secretKeyData, outputType: .BASE16, outputWidth: 78) {
    ///     let extractedString = String(data: extracted, encoding: .utf8)
    ///     print(extractedString ?? "")
    /// }
    /// ```
    public static func extract(input: Data, outputType: DataType, outputWidth: UInt) -> Data? {
        if input.isEmpty { return nil }
        
        guard let outputStream = create_empty_stream() else { return nil }
        
        let outputTypeC: data_type = switch outputType {
            case .AUTO: AUTO
            case .RAW: RAW
            case .BASE16: BASE16
        }
        
        let result = input.withUnsafeBytes { inputPtr in
            var inputStream = stream(
                buffer: UnsafeMutableRawPointer(mutating: inputPtr.baseAddress!).assumingMemoryBound(to: UInt8.self),
                size: CInt(input.count),
                pos: 0,
                memsize: CInt(input.count)
            )
            return CPaperkey.extract(&inputStream, outputStream, outputTypeC, CUnsignedInt(outputWidth))
        }
        
        defer {
            outputStream.pointee.buffer.deallocate()
            outputStream.deallocate()
        }
        
        if result != 0 { return nil }
        
        return Data(bytes: outputStream.pointee.buffer, count: Int(outputStream.pointee.size))
    }
    
    /// Restores an OpenPGP secret key from extracted paperkey data.
    ///
    /// This function reconstructs a complete OpenPGP secret key file from:
    /// 1. A public key file (contains the public key structure and user IDs)
    /// 2. The extracted secret data (from the extract function)
    ///
    /// The function combines these to create a usable GPG secret key file.
    ///
    /// - Parameters:
    ///   - pubring: The public key data as a Data object (GPG public key file)
    ///   - secrets: The extracted secret data from paperkey output
    ///   - inputType: The format of the secrets data (AUTO, RAW, or BASE16). Use AUTO for automatic detection.
    ///   - ignoreCRCError: If true, ignores CRC checksum errors during restoration (use with caution)
    /// - Returns: The restored complete OpenPGP secret key data, or nil if restoration fails
    ///
    /// # Example:
    /// ```swift
    /// let publicKeyData = Data(...) // Load your GPG public key
    /// let paperkeyData = Data(...) // Load the paperkey extract (from paper or file)
    /// if let restoredSecret = Paperkey.restore(pubring: publicKeyData, 
    ///                                          secrets: paperkeyData,
    ///                                          inputType: .AUTO,
    ///                                          ignoreCRCError: false) {
    ///     // Save the restored secret key
    ///     try? restoredSecret.write(to: URL(fileURLWithPath: "restored-sec.gpg"))
    /// }
    /// ```
    public static func restore(pubring: Data, secrets: Data, inputType: DataType, ignoreCRCError: Bool) -> Data? {
        if pubring.isEmpty || secrets.isEmpty { return nil }
        
        guard let outputStream = create_empty_stream() else { return nil }
        
        let inputTypeC: data_type = switch inputType {
            case .AUTO: AUTO
            case .RAW: RAW
            case .BASE16: BASE16
        }
        
        let result = pubring.withUnsafeBytes { pubringPtr in
            secrets.withUnsafeBytes { secretsPtr in
                var pubringStream = stream(
                    buffer: UnsafeMutableRawPointer(mutating: pubringPtr.baseAddress!).assumingMemoryBound(to: UInt8.self),
                    size: CInt(pubring.count),
                    pos: 0,
                    memsize: CInt(pubring.count)
                )
                
                var secretsStream = stream(
                    buffer: UnsafeMutableRawPointer(mutating: secretsPtr.baseAddress!).assumingMemoryBound(to: UInt8.self),
                    size: CInt(secrets.count),
                    pos: 0,
                    memsize: CInt(secrets.count)
                )
                
                return CPaperkey.restore(&pubringStream, &secretsStream, inputTypeC, outputStream, CInt(ignoreCRCError ? 1 : 0))
            }
        }
        
        defer {
            outputStream.pointee.buffer.deallocate()
            outputStream.deallocate()
        }
        
        if result != 0 { return nil }
        
        return Data(bytes: outputStream.pointee.buffer, count: Int(outputStream.pointee.size))
    }
}
