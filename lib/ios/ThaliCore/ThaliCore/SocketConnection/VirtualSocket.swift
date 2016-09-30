//
//  Thali CordovaPlugin
//  VirtualSocket.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import Foundation

/**
 `VirtualSocket` class manages non-TCP virtual socket.

 Non-TCP virtual socket is a combination of the non-TCP output and input streams
 */
public class VirtualSocket: NSObject {

    // MARK: - Internal state
    internal var didReadDataFromStreamHandler: ((VirtualSocket, NSData) -> Void)?
    internal var didCloseVirtualSocketHandler: (() -> Void)?

    // MARK: - Private state
    private var inputStream: NSInputStream
    private var outputStream: NSOutputStream

    // MARK: - Public methods
    init(with inputStream: NSInputStream, outputStream: NSOutputStream) {
        self.inputStream = inputStream
        self.outputStream = outputStream
        super.init()
        self.inputStream.delegate = self
        self.outputStream.delegate = self
    }

    func openStreams() {
        inputStream.scheduleInRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        inputStream.open()

        outputStream.scheduleInRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream.open()
    }

    func closeStreams() {
        inputStream.close()
        inputStream.removeFromRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)

        outputStream.close()
        outputStream.removeFromRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }

    func writeDataToOutputStream(data: NSData) {
        let dataLength = data.length
        let buffer: [UInt8] = Array(
            UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: dataLength)
        )

        let bytesWritten = outputStream.write(buffer, maxLength: dataLength)
        print("bytes written \(bytesWritten)")
        if bytesWritten < 0 {}
    }
}

// MARK: - NSStreamDelegate - Handling stream events
extension VirtualSocket: NSStreamDelegate {

    // MARK: - Delegate methods
    public func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        if aStream == self.inputStream {
            switch eventCode {
            case [.OpenCompleted]:
                print("event on input stream! OpenCompleted")
            case [.HasBytesAvailable]:
                print("event on input stream! HasBytesAvailable")
                let maxBufferLength = 1024
                var buffer = [UInt8](count: maxBufferLength, repeatedValue: 0)

                while self.inputStream.hasBytesAvailable {
                    let bytesReaded = self.inputStream.read(&buffer, maxLength: maxBufferLength)

                    if bytesReaded >= 0 {
                        print("readed \(bytesReaded) bytes on input stream")
                        let data = NSData(bytes: &buffer, length: bytesReaded)
                        didReadDataFromStreamHandler?(self, data)
                    }
                }
            case [.HasSpaceAvailable]:
                print("event on input stream! HasSpaceAvailable")
            case [.ErrorOccurred]:
                print("event on input stream! ErrorOccurred")
                didCloseVirtualSocketHandler?()
            case [.EndEncountered]:
                print("event on input stream! EndEncountered")
            default:
                print("new event on input stream! \(eventCode)")
                break
            }
        } else if aStream == self.outputStream {
            switch eventCode {
            case [.OpenCompleted]:
                print("event on output stream! OpenCompleted")
            case [.HasBytesAvailable]:
                print("event on output stream! HasBytesAvailable")
            case [.HasSpaceAvailable]:
                print("event on output stream! HasSpaceAvailable")
            case [.ErrorOccurred]:
                print("event on output stream! ErrorOccurred")
            case [.EndEncountered]:
                print("event on output stream! EndEncountered")
            default:
                print("new event on output stream! \(eventCode)")
                break
            }
        } else {
            self.inputStream.close()
            self.outputStream.close()
            aStream.close()
        }
    }
}
