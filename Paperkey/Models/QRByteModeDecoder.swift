//
//  QRByteModeDecoder.swift
//  Paperkey
//
//  Created by helmholtz on 2025/10/19.
//


import Foundation

struct QRByteModeDecoder {
    
    static func decode(from correctedData: Data?) -> Data? {
        guard let correctedData = correctedData else { return nil }
        
        let bitCount = correctedData.count * 8
        var bitPointer = 0
        
        func readBits(_ count: Int) -> Int? {
            guard bitPointer + count <= bitCount else { return nil }
            
            var value = 0
            for _ in 0..<count {
                let byteIndex = bitPointer / 8
                let bitIndex = 7 - (bitPointer % 8)
                let bit = (correctedData[byteIndex] >> bitIndex) & 1
                value = (value << 1) | Int(bit)
                bitPointer += 1
            }
            return value
        }
        
        func readNibble() -> UInt8? {
            guard let nibbleVal = readBits(4) else { return nil }
            return UInt8(nibbleVal)
        }
        
        func readByte() -> UInt8? {
            guard let byteVal = readBits(8) else { return nil }
            return UInt8(byteVal)
        }
        
        var output = Data()
        
        // first nibble: qrcode mode
        guard let _ = readNibble() else { return nil }
        
        // big-endian uint16: payload size
        guard let sizeUpper = readByte() else { return nil }
        guard let sizeLower = readByte() else { return nil }
        let payloadSize = UInt16(sizeUpper) << 8 + UInt16(sizeLower) & 0xff
        
        // data
        for _ in 0..<payloadSize {
            guard let newByte = readByte() else { return nil }
            output.append(newByte)
        }
        
        return output
    }
}
