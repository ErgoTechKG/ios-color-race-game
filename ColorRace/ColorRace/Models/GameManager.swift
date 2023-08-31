//
//  GameManager.swift
//  ColorRace
//
//  Created by Anup D'Souza on 29/08/23.
//

import Foundation
import SwiftUI
import Combine
import SocketIO

final class GameManager: ObservableObject {
    /// Game management
    @Published private(set) var gameState: GameState
    @State private(set) var gameMode: GameMode = .multiPlayer
    private var cancellable: AnyCancellable?
    
    /// SocketManager
    private var socketManager: SocketManager?
    private var socket: SocketIOClient?
    private let socketURL = URL(string: "http://localhost:3000")!
    private var namespace: String?
    private let loggingEnabled: Bool = false
    @Published private var socketState = SocketConnectionState.disconnected
    
    /// Game board
    private let tileColors: [UIColor] = [.red, .blue, .orange, .yellow, .green, .white]
    var boardColors: [[UIColor]] = []
    
    /// additional vars
    @Published private var showCardFlip: Bool = false
    
    init() {
        self.socketManager = SocketManager(socketURL: socketURL, config: [.log(loggingEnabled), .compress])
        self.socket = socketManager?.defaultSocket
        self.gameState = .disconnected(joinText: GameStrings.joinGame)
        self.cancellable = $socketState
            .sink { [weak self] socketState in
                print("gm: received socket event: \(socketState)")
                self?.updateGameState(forSocketState: socketState)
            }
    }
    
    deinit {
        cancellable?.cancel()
        cancellable = nil
        socketManager = nil
        socket = nil
    }
}

extension GameManager {
    
    func joinGame() {
        closeConnection()
        establishConnection()
    }
    
    func quitGame() {
        closeConnection()
    }

    private func setupBoard() {
        showCardFlip = true
        generateRandomBoardColors()
    }
    
    private func generateRandomBoardColors() {
        boardColors = (0..<3).map { _ in
            return (0..<3).map { _ in
                return tileColors.randomElement() ?? .white
            }
        }
        print(boardColors)
    }

    private func updateGameState(forSocketState socketState: SocketConnectionState) {
        switch socketState {
        case .disconnected, .userDisconnected:
            gameState = .disconnected(joinText: GameStrings.joinGame)
        case .userConnected, .userJoined, .opponentDisconnected:
            gameState = .connectingToOpponent(connectionText: GameStrings.waitingForOpponent)
        case .opponentJoined:
            gameState = (gameState == .playing || gameState == .preparingGame) ? gameState : .connectingToOpponent(connectionText: GameStrings.waitingForOpponent)
        case .gameStarted: // TODO: handle gameStarted event possibly being called multiple times
            setupBoard()
//            gameState = .playing
            gameState = .preparingGame
        }
    }
}

extension GameManager {
    
    private func addEventListeners() {
        
        socket?.on(SocketEvents.userConnected) { [weak self] data, _ in
            guard let data = data.first as? String else {
                print("client => received event: \(SocketEvents.userConnected), failed to read namespace")
                return
            }
            print("client => received event: \(SocketEvents.userConnected), namespace: \(data)")
            self?.namespace = data
//            self?.gameState = .connectingToOpponent
            self?.socketState = .userConnected
        }
        
        socket?.on(SocketEvents.userJoined) { [weak self] data, _ in
            guard let data = data.first as? String else {
                print("client => received event: \(SocketEvents.userJoined), failed to read user socket id")
                return
            }
            if let socketId = self?.socket?.sid, socketId == data {
                print("client => received event: \(SocketEvents.userJoined), socket id(self):\(data)")
//                self?.gameState = .connectingToOpponent
                self?.socketState = .userJoined
            } else {
                print("client => received event: \(SocketEvents.userJoined), socket id(other):\(data)")
                self?.socketState = .opponentJoined
//                if self?.gameState != .playing {
//                    self?.gameState = .connectingToOpponent
//                }
            }
        }
        
        socket?.on(SocketEvents.gameStarted) { [weak self] data, _ in
            guard let data = data.first as? String else {
                print("client => received event: \(SocketEvents.gameStarted), failed to read namespace")
                return
            }
            
            if let namespace = self?.namespace, namespace == data {
                print("client => received event: \(SocketEvents.gameStarted), namespace(self):\(data)")
//                self?.gameState = .playing
                self?.socketState = .gameStarted
            } else {
                print("client => received event: \(SocketEvents.gameStarted), namespace(other):\(data)")
//                self?.gameState = .connectingToOpponent
                self?.socketState = .gameStarted
            }
        }
        
        socket?.on(SocketEvents.userDisconnected) { [weak self] data, _ in
            guard let data = data.first as? String else {
                print("client => received event: \(SocketEvents.userDisconnected), failed to read namespace")
                return
            }
            
            if let socketId = self?.socket?.sid, socketId == data {
                print("client => received event: \(SocketEvents.userDisconnected), socket id(self):\(data)")
                self?.namespace = nil
//                self?.gameState = .disconnected
                self?.socketState = .userDisconnected
            } else {
                print("client => received event: \(SocketEvents.userDisconnected), socket id(other):\(data)")
//                self?.gameState = .connectingToOpponent
                self?.socketState = .opponentDisconnected
            }
        }

    }

    private func establishConnection() {
//        gameState = .connectingToServer
        addEventListeners()
        socket?.connect()
    }
    
    private func closeConnection() {
        socketState = .disconnected
        guard let namespace = namespace else {
            socket?.disconnect()
            return
        }
        socket?.emit("disconnectNamespace", namespace)
        socket?.disconnect()
    }
}