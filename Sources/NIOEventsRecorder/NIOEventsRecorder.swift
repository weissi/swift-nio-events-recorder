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
import Foundation
import NIOTransportServices

public final class NIOChannelEventsRecorder<In: Codable, Out: Codable>: ChannelDuplexHandler {
    public typealias InboundIn = In
    public typealias InboundOut = In
    public typealias OutboundOut = Out
    public typealias OutboundIn = Out


    private var eventBuffer: [TimedEvent<In, Out>] = []
    private var start = NIODeadline.now()
    private let allEvents: EventLoopPromise<EventRecording<In, Out>>

    private var currentInterval: TimeAmount {
        return NIODeadline.now() - self.start
    }

    private func eventBufferAppend(_ event: Event<In, Out>) {
        self.eventBuffer.append(TimedEvent(timeSinceFirst: self.currentInterval, event: event))
    }


    public init(allEvents: EventLoopPromise<EventRecording<In, Out>>) {
        self.allEvents = allEvents
    }

    public func register(context: ChannelHandlerContext, promise: EventLoopPromise<Void>?) {
        self.eventBufferAppend(.outbound(.register))
        let promise = promise ?? context.eventLoop.makePromise()
        promise.futureResult.whenComplete { result in
            self.eventBufferAppend(.result(.registerResult(result.errorOrNil)))
        }
        context.register(promise: promise)
    }

    public func bind(context: ChannelHandlerContext, to: SocketAddress, promise: EventLoopPromise<Void>?) {
        self.eventBufferAppend(.outbound(.bind(to)))
        let promise = promise ?? context.eventLoop.makePromise()
        promise.futureResult.whenComplete { result in
            self.eventBufferAppend(.result(.bindResult(result.errorOrNil)))
        }
        context.bind(to: to, promise: promise)
    }

    public func connect(context: ChannelHandlerContext, to: SocketAddress, promise: EventLoopPromise<Void>?) {
        self.eventBufferAppend(.outbound(.connect(to)))
        let promise = promise ?? context.eventLoop.makePromise()
        promise.futureResult.whenComplete { result in
            self.eventBufferAppend(.result(.connectResult(result.errorOrNil)))
        }
        context.connect(to: to, promise: promise)
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        self.eventBufferAppend(.outbound(.write(self.unwrapOutboundIn(data))))
        let promise = promise ?? context.eventLoop.makePromise()
        promise.futureResult.whenComplete { result in
            self.eventBufferAppend(.result(.writeResult(result.errorOrNil)))
        }
        context.write(data, promise: promise)
    }

    public func flush(context: ChannelHandlerContext) {
        defer {
            context.flush()
        }
        self.eventBufferAppend(.outbound(.flush))
    }

    public func read(context: ChannelHandlerContext) {
        defer {
            context.read()
        }
        self.eventBufferAppend(.outbound(.read))
    }

    public func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        self.eventBufferAppend(.outbound(.close(mode)))
        let promise = promise ?? context.eventLoop.makePromise()
        promise.futureResult.whenComplete { result in
            self.eventBufferAppend(.result(.closeResult(result.errorOrNil)))
        }
        context.close(promise: promise)
    }

    public func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        self.eventBufferAppend(.outbound(.triggerUserOutboundEvent(.init(event))))
        let promise = promise ?? context.eventLoop.makePromise()
        promise.futureResult.whenComplete { result in
            self.eventBufferAppend(.result(.triggerUserOutboundEventResult(result.errorOrNil)))
        }
        context.triggerUserOutboundEvent(event, promise: promise)
    }

    public func channelRegistered(context: ChannelHandlerContext) {
        defer {
            context.fireChannelRegistered()
        }
        self.eventBufferAppend(.inbound(.channelRegistered))
    }

    public func channelUnregistered(context: ChannelHandlerContext) {
        defer {
            context.fireChannelUnregistered()
        }
        self.eventBufferAppend(.inbound(.channelUnregistered))
    }

    public func channelActive(context: ChannelHandlerContext) {
        defer {
            context.fireChannelActive()
        }
        self.eventBufferAppend(.inbound(.channelActive))
    }

    public func channelInactive(context: ChannelHandlerContext) {
        defer {
            context.fireChannelInactive()
        }
        self.eventBufferAppend(.inbound(.channelInactive))
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        defer {
            context.fireChannelRead(data)
        }
        self.eventBufferAppend(.inbound(.channelRead(self.unwrapInboundIn(data))))
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        defer {
            context.fireChannelReadComplete()
        }
        self.eventBufferAppend(.inbound(.channelReadComplete))
    }

    public func channelWritabilityChanged(context: ChannelHandlerContext) {
        defer {
            context.fireChannelWritabilityChanged()
        }
        self.eventBufferAppend(.inbound(.channelWritabilityChanged))
    }

    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        defer {
            context.fireUserInboundEventTriggered(event)
        }
        self.eventBufferAppend(.inbound(.userInboundEventTriggered(.init(event))))
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        defer {
            context.fireErrorCaught(error)
        }
        self.eventBufferAppend(.inbound(.errorCaught(.init(error))))
    }

    public func handlerAdded(context: ChannelHandlerContext) {
        self.start = NIODeadline.now()
    }

    public func handlerRemoved(context: ChannelHandlerContext) {
        self.allEvents.succeed(EventRecording(events: self.eventBuffer))
    }
}

