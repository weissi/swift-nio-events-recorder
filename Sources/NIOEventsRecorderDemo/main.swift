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

import Foundation
import NIO
import NIOEventsRecorder

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
defer {
    try! group.syncShutdownGracefully()
}

let client = try! ClientBootstrap(group: group)
    .channelInitializer { channel in
        let promise = channel.eventLoop.makePromise(of: EventRecording<ByteBuffer, ByteBuffer>.self)

        promise.futureResult.whenSuccess { recording in
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encoded = try! encoder.encode(recording)
            print(String(decoding: encoded, as: Unicode.UTF8.self))

            print(try! JSONDecoder().decode(EventRecording<ByteBuffer, ByteBuffer>.self, from: encoded))
        }
        return channel.pipeline.addHandler(NIOChannelEventsRecorder<ByteBuffer, ByteBuffer>(allEvents: promise))
}
    .connect(host: "google.com", port: 80)
    .wait()

var buffer = client.allocator.buffer(capacity: 128)
buffer.writeString("GET / HTTP/1.1\r\nhost: google.com\r\n\r\n")

try! client.writeAndFlush(buffer).wait()
sleep(1)
