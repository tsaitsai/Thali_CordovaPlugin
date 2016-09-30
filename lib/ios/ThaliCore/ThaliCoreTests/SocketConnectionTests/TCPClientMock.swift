//
//  Thali CordovaPlugin
//  TCPClientMock.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//


import Foundation
import ThaliCore

class TCPClientMock: NSObject {

    private let tcpClient: GCDAsyncSocket
    private let socketQueue = dispatch_queue_create(
        "org.thaliproject.TCPClientMock.GCDAsyncSocket.delegateQueue",
        DISPATCH_QUEUE_CONCURRENT
    )
    private var didReadDataHandler: (NSData) -> Void
    private var didConnectHandler: () -> Void
    private var didDisconnectHandler: () -> Void


    init(readDataHandler: (NSData) -> Void,
         connectHandler: () -> Void,
         disconnectHandler: () -> Void) {
        tcpClient = GCDAsyncSocket()
        didReadDataHandler = readDataHandler
        didConnectHandler = connectHandler
        didDisconnectHandler = disconnectHandler
        super.init()
        tcpClient.delegate = self
        tcpClient.delegateQueue = socketQueue
    }

    func connectToLocalHost(on port: UInt16, errorHandler: (ErrorType) -> Void) {
        do {
            try tcpClient.connectToHost("127.0.0.1", onPort: port)
        } catch let error {
            errorHandler(error)
        }
    }

    func disconnect() {
        if tcpClient.isConnected {
            tcpClient.disconnectAfterReadingAndWriting()
        } else {
            print("Fake client is already disconnected")
        }
    }

    func send(message: String) {
        let messageData = message.dataUsingEncoding(NSUTF8StringEncoding)
        tcpClient.writeData(messageData!, withTimeout: -1, tag: 0)
        print("Fake client has sended special message")
    }

    func sendRandomMessage(length length: Int) {
        let randomMessage = String.random(length: length)
        let messageData = randomMessage.dataUsingEncoding(NSUTF8StringEncoding)
        tcpClient.writeData(messageData!, withTimeout: -1, tag: 0)
        print("Fake client has sended random message")
    }
}

extension TCPClientMock: GCDAsyncSocketDelegate {

    func socketDidDisconnect(sock: GCDAsyncSocket, withError err: NSError?) {
        print("Fake client is disconnected")
        didDisconnectHandler()
    }

    func socket(sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Fake client connected to host")
        sock.readDataWithTimeout(-1, tag: 0)
        didConnectHandler()
    }

    func socket(sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("Fake client did write data to socket")
    }

    func socket(sock: GCDAsyncSocket, didReadData data: NSData, withTag tag: Int) {
        print("Fake client did read data from socket")
        didReadDataHandler(data)
    }

    func socketDidCloseReadStream(sock: GCDAsyncSocket) {}
}
