//
//  Thali CordovaPlugin
//  TCPServerMock.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//


import Foundation
import ThaliCore

class TCPServerMock: NSObject {

    private let tcpListener: GCDAsyncSocket
    private let socketQueue = dispatch_queue_create(
        "org.thaliproject.TCPServerMock.GCDAsyncSocket.delegateQueue",
        DISPATCH_QUEUE_CONCURRENT
    )
    private var activeConnections: Atomic<[GCDAsyncSocket]> = Atomic([])

    private var didAcceptNewSocket: () -> Void
    private var didReadData: (NSData) -> Void
    private var didDisconnectHandler: () -> Void



    init(acceptSocketHandler: () -> Void,
         readDataHandler: (NSData) -> Void,
         disconnectHandler: () -> Void) {
        tcpListener = GCDAsyncSocket()
        didAcceptNewSocket = acceptSocketHandler
        didReadData = readDataHandler
        didDisconnectHandler = disconnectHandler
        super.init()
        tcpListener.delegate = self
        tcpListener.delegateQueue = socketQueue
    }

    /**
     Start listener on localhost.

     - parameters:
       - port:
         TCP port number that listens for incoming connections.

         Default value is 0 which means any available port.

     - returns:
       0 - if listener can't be started

       nubmer of port (1 - 65535) that listens for connections.
     */
    func startListening(on port: UInt16 = 0) -> UInt16 {
        do {
            try tcpListener.acceptOnPort(port)
            return tcpListener.localPort
        } catch _ {
            return 0
        }
    }

    func disconnectAllConnections() {
        activeConnections.modify {
            $0.forEach { $0.disconnect() }
            $0.removeAll()
        }
//        if tcpListener.isConnected {
//            tcpListener.disconnectAfterReadingAndWriting()
//        } else {
//            print("already disconnected")
//        }
    }

    func sendRandomMessage(length length: Int) {
        let randomMessage = String.random(length: length)
        let messageData = randomMessage.dataUsingEncoding(NSUTF8StringEncoding)

        guard let clientSocket = activeConnections.value.first else {
            return
        }

        clientSocket.writeData(messageData!, withTimeout: -1, tag: 0)
    }

    func send(message: String) {
        let messageData = message.dataUsingEncoding(NSUTF8StringEncoding)

        guard let clientSocket = activeConnections.value.first else {
            return
        }

        clientSocket.writeData(messageData!, withTimeout: -1, tag: 0)
    }
}

extension TCPServerMock: GCDAsyncSocketDelegate {

    func socket(sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("Fake server accepted new connection on \(sock.localPort)")
        activeConnections.modify { $0.append(newSocket) }
        newSocket.readDataWithTimeout(-1, tag: 1)
        didAcceptNewSocket()
    }

    func socketDidDisconnect(sock: GCDAsyncSocket, withError err: NSError?) {
        activeConnections.modify {
            if let indexOfDisconnectedSocket = $0.indexOf(sock) {
                $0.removeAtIndex(indexOfDisconnectedSocket)
            }
        }
        didDisconnectHandler()
    }

    func socket(sock: GCDAsyncSocket, didReadData data: NSData, withTag tag: Int) {
        print("Fake server did read data from socket")
        didReadData(data)
    }

    func socket(sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {}
    func socket(sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("Fake server did write data to socket")
    }
    func socketDidCloseReadStream(sock: GCDAsyncSocket) {}
}
