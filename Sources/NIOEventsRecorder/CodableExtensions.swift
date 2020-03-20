//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import struct Foundation.Data

extension Result where Success == Void, Failure == Error {
    var errorOrNil: ErrorString? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return ErrorString(error)
        }
    }
}

extension SocketAddress: Codable {
    public enum CodingKeys: String, CodingKey {
        case type
        case address
        case port
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let address = try container.decode(String.self, forKey: .address)
        switch type {
        case "v4", "v6":
            let port = try container.decode(Int.self, forKey: .port)
            self = try SocketAddress(ipAddress: address, port: port)
        case "unix":
            self = try .init(unixDomainSocketPath: address)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "\(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .v4:
            try container.encode("v4", forKey: .type)
            try container.encode(self.ipAddress, forKey: .address)
            try container.encode(self.port, forKey: .port)
        case .v6:
            try container.encode("v6", forKey: .type)
            try container.encode(self.ipAddress, forKey: .address)
            try container.encode(self.port, forKey: .port)
        case .unixDomainSocket(let payload):
            try container.encode("unix", forKey: .type)
            var address = payload.address
            try withUnsafeBytes(of: &address.sun_path) { ptr in
                try container.encode(String(decoding: ptr.prefix(while: { $0 != 0 }), as: Unicode.UTF8.self),
                                     forKey: .address)
            }
        }
    }
}

extension ByteBuffer: Codable {
    public init(from decoder: Decoder) throws {
        let data = try decoder.singleValueContainer().decode(Data.self)
        self = ByteBufferAllocator().buffer(capacity: data.count)
        self.writeBytes(data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var copy = self
        try container.encode(copy.readData(length: copy.readableBytes))
    }
}

extension TimeAmount: Codable {
    public init(from decoder: Decoder) throws {
        self = TimeAmount.nanoseconds(try decoder.singleValueContainer().decode(Int64.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.nanoseconds)
    }
}

extension CloseMode: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let which = try container.decode(String.self)
        switch which {
        case "input":
            self = .input
        case "output":
            self = .output
        case "all":
            self = .all
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(which)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .input:
            try container.encode("input")
        case .output:
            try container.encode("output")
        case .all:
            try container.encode("all")
        }
    }

}
