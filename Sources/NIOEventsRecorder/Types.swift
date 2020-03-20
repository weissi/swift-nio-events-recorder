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
import enum Network.NWEndpoint
import struct Network.IPv4Address
import struct Network.IPv6Address
import struct Foundation.Data
import struct Foundation.URL

public struct ErrorString: Codable {
    public var type: String
    public var description: String

    public init(_ error: Error) {
        self.type = String(describing: Swift.type(of: error))
        self.description = String(describing: error)
    }
}


public struct InboundUserEvent: Codable {
    public enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum Underlying {
        case channelEvent(ChannelEvent)
        case other(AnyString)
    }

    private var underlying: Underlying

    public init(_ any: Any) {
        switch any {
        case let channelEvent as ChannelEvent:
            self.underlying = .channelEvent(channelEvent)
        default:
            self.underlying = .other(AnyString(any))
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "inputClosed":
            self.underlying = .channelEvent(.inputClosed)
        case "outputClosed":
            self.underlying = .channelEvent(.outputClosed)
        case "other":
            self.underlying = .other(try container.decode(AnyString.self, forKey: .payload))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "\(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self.underlying {
        case .channelEvent(.inputClosed):
            try container.encode("inputClosed", forKey: .type)
        case .channelEvent(.outputClosed):
            try container.encode("outputClosed", forKey: .type)
        case .other(let payload):
            try container.encode("other", forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }

}

public struct OutboundUserEvent: Codable {
    public enum CodingKeys: String, CodingKey {
        case type
        case subType
        case payload1
        case payload2
        case payload3
        case payload4
    }

    private enum Underlying {
        case connectToNWEndpoint(NWEndpoint)
        case bindToNWEndpoint(NWEndpoint)
        case other(AnyString)
    }

    private var underlying: Underlying

    public init(_ any: Any) {
        switch any {
        default:
            self.underlying = .other(AnyString(any))
        }
    }

    public init(from decoder: Decoder) throws {
        func decodeNWEndpoint(_ endpoint: String,
                              container: KeyedDecodingContainer<OutboundUserEvent.CodingKeys>) throws -> NWEndpoint {
            switch endpoint {
            case "hostname":
                let hostName = try container.decode(String.self, forKey: .payload1)
                guard let port = NWEndpoint.Port(rawValue: try container.decode(UInt16.self, forKey: .payload3)) else {
                    throw DecodingError.dataCorruptedError(forKey: .payload3,
                                                           in: container,
                                                           debugDescription: "port illegal")
                }
                return .hostPort(host: .name(hostName, nil), port: port)
            case "ipv4":
                guard let ip = IPv4Address(try container.decode(Data.self, forKey: .payload1)) else {
                    throw DecodingError.dataCorruptedError(forKey: .payload1,
                                                           in: container,
                                                           debugDescription: "ip illegal")
                }
                guard let port = NWEndpoint.Port(rawValue: try container.decode(UInt16.self, forKey: .payload3)) else {
                    throw DecodingError.dataCorruptedError(forKey: .payload3,
                                                           in: container,
                                                           debugDescription: "port illegal")
                }
                return .hostPort(host: .ipv4(ip), port: port)
            case "ipv6":
                guard let ip = IPv6Address(try container.decode(Data.self, forKey: .payload1)) else {
                    throw DecodingError.dataCorruptedError(forKey: .payload1,
                                                           in: container,
                                                           debugDescription: "ip illegal")
                }
                guard let port = NWEndpoint.Port(rawValue: try container.decode(UInt16.self, forKey: .payload3)) else {
                    throw DecodingError.dataCorruptedError(forKey: .payload3,
                                                           in: container,
                                                           debugDescription: "port illegal")
                }
                return .hostPort(host: .ipv6(ip), port: port)
            case "service":
                let name = try container.decode(String.self, forKey: .payload1)
                let type = try container.decode(String.self, forKey: .payload2)
                let domain = try container.decode(String.self, forKey: .payload4)
                return .service(name: name, type: type, domain: domain, interface: nil)
            case "unix":
                let path = try container.decode(String.self, forKey: .payload1)
                return .unix(path: path)
            case "url":
                let url = try container.decode(URL.self, forKey: .payload1)
                return .url(url)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "\(endpoint)")
            }

        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let subType = try container.decode(String.self, forKey: .subType)
        switch (type, subType) {
        case ("other", _):
            self.underlying = .other(try container.decode(AnyString.self, forKey: .payload1))
        case ("connect-nw-endpoint", let endpoint):
            self.underlying = .connectToNWEndpoint(try decodeNWEndpoint(endpoint, container: container))
        case ("bind-nw-endpoint", let endpoint):
            self.underlying = .bindToNWEndpoint(try decodeNWEndpoint(endpoint, container: container))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "\(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        func encodeNWEndpoint(_ payload: NWEndpoint,
                              container: inout KeyedEncodingContainer<OutboundUserEvent.CodingKeys>) throws {
            switch payload {
            case .hostPort(host: .name(let hostName, let interface), port: let port):
                try container.encode("hostname", forKey: .subType)
                try container.encode(hostName, forKey: .payload1)
                try container.encode(interface?.name, forKey: .payload2)
                try container.encode(port.rawValue, forKey: .payload3)
            case .hostPort(host: .ipv4(let ip), port: let port):
                try container.encode("ipv4", forKey: .subType)
                try container.encode(ip.rawValue, forKey: .payload1)
                try container.encode(port.rawValue, forKey: .payload3)
            case .hostPort(host: .ipv6(let ip), port: let port):
                try container.encode("ipv6", forKey: .subType)
                try container.encode(ip.rawValue, forKey: .payload1)
                try container.encode(port.rawValue, forKey: .payload3)
            case .service(name: let name, type: let type, domain: let domain, interface: let interface):
                try container.encode("service", forKey: .subType)
                try container.encode(name, forKey: .payload1)
                try container.encode(type, forKey: .payload2)
                try container.encode(domain, forKey: .payload3)
                try container.encode(interface?.name, forKey: .payload4)
            case .unix(path: let path):
                try container.encode("unix", forKey: .subType)
                try container.encode(path, forKey: .payload1)
            case .url(let url):
                try container.encode("url", forKey: .subType)
                try container.encode(url, forKey: .payload1)
            @unknown default:
                throw EncodingError.invalidValue(payload, .init(codingPath: [CodingKeys.type],
                                                                debugDescription: "\(payload)"))
            }
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self.underlying {
        case .other(let payload):
            try container.encode("other", forKey: .type)
            try container.encode(payload, forKey: .payload1)
        case .connectToNWEndpoint(let payload):
            let type = "connect-nw-endpoint"
            try container.encode(type, forKey: .type)
            try encodeNWEndpoint(payload, container: &container)
        case .bindToNWEndpoint(let payload):
            let type = "bind-nw-endpoint"
            try container.encode(type, forKey: .type)
            try encodeNWEndpoint(payload, container: &container)
        }
    }

}

public struct AnyString: Codable {
    public var type: String
    public var description: String

    public init(_ any: Any) {
        self.type = String(describing: Swift.type(of: any))
        self.description = String(describing: any)
    }
}

public enum Event<In: Codable, Out: Codable>: Codable {
    public enum CodingKeys: String, CodingKey {
        case type
        case subType
        case payload
    }
    case inbound(Inbound)
    case outbound(Outbound)
    case result(OutboundResult)

    public enum Outbound {
        case register
        case bind(SocketAddress)
        case connect(SocketAddress)
        case write(Out)
        case flush
        case read
        case close(CloseMode)
        case triggerUserOutboundEvent(OutboundUserEvent)
    }

    public enum OutboundResult {
        case registerResult(ErrorString?)
        case bindResult(ErrorString?)
        case connectResult(ErrorString?)
        case writeResult(ErrorString?)
        case closeResult(ErrorString?)
        case triggerUserOutboundEventResult(ErrorString?)
    }

    public enum Inbound {
        public enum CodingKeys: String, CodingKey {
            case type
            case payload
        }

        case channelRegistered
        case channelUnregistered
        case channelActive
        case channelInactive
        case channelRead(In)
        case channelReadComplete
        case channelWritabilityChanged
        case userInboundEventTriggered(InboundUserEvent)
        case errorCaught(ErrorString)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let subType = try container.decode(String.self, forKey: .subType)

        switch (type, subType) {
        case ("inbound", "channelUnregistered"):
            self = .inbound(.channelUnregistered)

        case ("inbound", "channelActive"):
            self = .inbound(.channelActive)

        case ("inbound", "channelInactive"):
            self = .inbound(.channelInactive)

        case ("inbound", "channelRead"):
            self = .inbound(.channelRead(try container.decode(In.self, forKey: .payload)))

        case ("inbound", "channelReadComplete"):
            self = .inbound(.channelReadComplete)

        case ("inbound", "channelWritabilityChanged"):
            self = .inbound(.channelWritabilityChanged)

        case ("inbound", "userInboundEventTriggered"):
            self = .inbound(.userInboundEventTriggered(try container.decode(InboundUserEvent.self, forKey: .payload)))

        case ("inbound", "errorCaught"):
            self = .inbound(.errorCaught(try container.decode(ErrorString.self, forKey: .payload)))

        case ("inbound", "channelRegistered"):
            self = .inbound(.channelRegistered)

        case ("outbound", "register"):
            self = .outbound(.register)

        case ("outbound", "bind"):
            self = .outbound(.bind(try container.decode(SocketAddress.self, forKey: .payload)))

        case ("outbound", "connect"):
            self = .outbound(.connect(try container.decode(SocketAddress.self, forKey: .payload)))

        case ("outbound", "write"):
            self = .outbound(.write(try container.decode(Out.self, forKey: .payload)))

        case ("outbound", "flush"):
            self = .outbound(.flush)

        case ("outbound", "read"):
            self = .outbound(.read)

        case ("outbound", "close"):
            self = .outbound(.close(try container.decode(CloseMode.self, forKey: .payload)))

        case ("outbound", "triggerUserOutboundEvent"):
            self = .outbound(.triggerUserOutboundEvent(try container.decode(OutboundUserEvent.self, forKey: .payload)))

        case ("result", "registerResult"):
            self = .result(.registerResult(try container.decode(Optional<ErrorString>.self, forKey: .payload)))

        case ("result", "bindResult"):
            self = .result(.bindResult(try container.decode(Optional<ErrorString>.self, forKey: .payload)))

        case ("result", "connectResult"):
            self = .result(.connectResult(try container.decode(Optional<ErrorString>.self, forKey: .payload)))

        case ("result", "writeResult"):
            self = .result(.writeResult(try container.decode(Optional<ErrorString>.self, forKey: .payload)))

        case ("result", "closeResult"):
            self = .result(.closeResult(try container.decode(Optional<ErrorString>.self, forKey: .payload)))

        case ("result", "triggerUserOutboundEventResult"):
            self = .result(.triggerUserOutboundEventResult(try container.decode(Optional<ErrorString>.self, forKey: .payload)))

        case (let type, let subType):
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.type,
                                                   in: container,
                                                   debugDescription: "\(type).\(subType) is illegal")
        }
    }


    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .inbound(.channelUnregistered):
            try container.encode("inbound", forKey: .type)
            try container.encode("channelUnregistered", forKey: .subType)

        case .inbound(.channelActive):
            try container.encode("inbound", forKey: .type)
            try container.encode("channelActive", forKey: .subType)

        case .inbound(.channelInactive):
            try container.encode("inbound", forKey: .type)
            try container.encode("channelInactive", forKey: .subType)

        case .inbound(.channelRead(let payload)):
            try container.encode("inbound", forKey: .type)
            try container.encode("channelRead", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .inbound(.channelReadComplete):
            try container.encode("inbound", forKey: .type)
            try container.encode("channelReadComplete", forKey: .subType)

        case .inbound(.channelWritabilityChanged):
            try container.encode("inbound", forKey: .type)
            try container.encode("channelWritabilityChanged", forKey: .subType)

        case .inbound(.userInboundEventTriggered(let payload)):
            try container.encode("inbound", forKey: .type)
            try container.encode("userInboundEventTriggered", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .inbound(.errorCaught(let payload)):
            try container.encode("inbound", forKey: .type)
            try container.encode("errorCaught", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .inbound(.channelRegistered):
            try container.encode("inbound", forKey: .type)
            try container.encode("channelRegistered", forKey: .subType)

        case .outbound(.register):
            try container.encode("outbound", forKey: .type)
            try container.encode("register", forKey: .subType)

        case .outbound(.bind(let payload)):
            try container.encode("outbound", forKey: .type)
            try container.encode("bind", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .outbound(.connect(let payload)):
            try container.encode("outbound", forKey: .type)
            try container.encode("connect", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .outbound(.write(let payload)):
            try container.encode("outbound", forKey: .type)
            try container.encode("write", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .outbound(.flush):
            try container.encode("outbound", forKey: .type)
            try container.encode("flush", forKey: .subType)

        case .outbound(.read):
            try container.encode("outbound", forKey: .type)
            try container.encode("read", forKey: .subType)

        case .outbound(.close(let payload)):
            try container.encode("outbound", forKey: .type)
            try container.encode("close", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .outbound(.triggerUserOutboundEvent(let payload)):
            try container.encode("outbound", forKey: .type)
            try container.encode("triggerUserOutboundEvent", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .result(.registerResult(let payload)):
            try container.encode("result", forKey: .type)
            try container.encode("registerResult", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .result(.bindResult(let payload)):
            try container.encode("result", forKey: .type)
            try container.encode("bindResult", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .result(.connectResult(let payload)):
            try container.encode("result", forKey: .type)
            try container.encode("connectResult", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .result(.writeResult(let payload)):
            try container.encode("result", forKey: .type)
            try container.encode("writeResult", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .result(.closeResult(let payload)):
            try container.encode("result", forKey: .type)
            try container.encode("closeResult", forKey: .subType)
            try container.encode(payload, forKey: .payload)

        case .result(.triggerUserOutboundEventResult(let payload)):
            try container.encode("result", forKey: .type)
            try container.encode("triggerUserOutboundEventResult", forKey: .subType)
            try container.encode(payload, forKey: .payload)
        }
    }
}

public struct TimedEvent<In: Codable, Out: Codable>: Codable {
    public var timeSinceFirst: TimeAmount
    public var event: Event<In, Out>
}

public struct EventRecording<In: Codable, Out: Codable>: Codable {
    public var events: [TimedEvent<In, Out>]
}
