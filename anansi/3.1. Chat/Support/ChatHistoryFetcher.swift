//
//  ChatHistoryFetcher.swift
//  anansi
//
//  Created by João Nuno Gaspar Apura on 26/06/2019.
//  Copyright © 2019 João Apura. All rights reserved.
//
/*
import UIKit

protocol ChatHistoryDelegate: class {
    func chatHistory(isEmpty: Bool)
    func chatHistory(updated messages: [Message], at indexPaths: [IndexPath])
}

class ChatHistoryFetcher: NSObject {
    
    
}

    weak var delegate: ChatHistoryDelegate?
    
    fileprivate var loadingGroup = DispatchGroup()
    fileprivate let messagesFetcher = MessagesFetcher()
    
    fileprivate var messages = [Message]()
    fileprivate var conversation: Conversation?
    
    fileprivate var isGroupChat: Bool!
    fileprivate var messagesToLoad: Int!
    
    public func loadPreviousMessages(_ messages: [Message], _ conversation: Conversation,
                                     _ messagesToLoad: Int, _ isGroupChat: Bool) {
        self.messages = messages
        self.conversation = conversation
        self.messagesToLoad = messagesToLoad
        self.isGroupChat = isGroupChat
        loadChatHistory()
    }
    
    fileprivate func loadChatHistory() {
        guard let currentUserID = Auth.auth().currentUser?.uid, let conversationID = conversation?.chatID else { return }
        if messages.count <= 0 { delegate?.chatLogHistory(isEmpty: true) }
        getFirstID(currentUserID, conversationID)
    }
    
    fileprivate func getFirstID(_ currentUserID: String, _ conversationID: String) {
        let firstIDReference = Database.database().reference().child("user-messages")
            .child(currentUserID).child(conversationID).child(userMessagesFirebaseFolder)
        
        let numberOfMessagesToLoad = messagesToLoad + messages.count
        let firstIDQuery = firstIDReference.queryLimited(toLast: UInt(numberOfMessagesToLoad))
        firstIDQuery.observeSingleEvent(of: .childAdded, with: { (snapshot) in
            let firstID = snapshot.key
            self.getLastID(firstID, currentUserID, conversationID)
        })
    }
    
    fileprivate func getLastID(_ firstID: String, _ currentUserID: String, _ conversationID: String) {
        let nextMessageIndex = messages.count + 1
        let lastIDReference = Database.database().reference().child("user-messages")
            .child(currentUserID).child(conversationID).child(userMessagesFirebaseFolder)
        let lastIDQuery = lastIDReference.queryLimited(toLast: UInt(nextMessageIndex))
        
        lastIDQuery.observeSingleEvent(of: .childAdded, with: { (snapshot) in
            let lastID = snapshot.key
            
            if (firstID == lastID) && self.messages.contains(where: { (message) -> Bool in
                return message.messageUID == lastID
            }) {
                self.delegate?.chatLogHistory(isEmpty: false)
                return
            }
            
            self.getRange(firstID, lastID, currentUserID, conversationID)
        })
    }
    
    fileprivate func getRange(_ firstID: String, _ lastID: String, _ currentUserID: String, _ conversationID: String) {
        let rangeReference = Database.database().reference().child("user-messages")
            .child(currentUserID).child(conversationID).child(userMessagesFirebaseFolder)
        let rangeQuery = rangeReference.queryOrderedByKey().queryStarting(atValue: firstID).queryEnding(atValue: lastID)
        
        rangeQuery.observeSingleEvent(of: .value, with: { (snapshot) in
            for _ in 0 ..< snapshot.childrenCount { self.loadingGroup.enter() }
            self.notifyWhenGroupFinished(query: rangeQuery)
            self.getMessages(from: rangeQuery)
        })
    }
    
    fileprivate var userMessageHande: DatabaseHandle!
    var previousMessages = [Message]()
    fileprivate func getMessages(from query: DatabaseQuery) {
        previousMessages = [Message]()
        self.userMessageHande = query.observe(.childAdded, with: { (snapshot) in
            let messageUID = snapshot.key
            self.getMetadata(fromMessageWith: messageUID)
        })
    }
    
    fileprivate func getMetadata(fromMessageWith messageUID: String) {
        let reference = Database.database().reference().child("messages").child(messageUID)
        
        reference.observeSingleEvent(of: .value, with: { (snapshot) in
            guard var dictionary = snapshot.value as? [String: AnyObject] else { return }
            dictionary.updateValue(messageUID as AnyObject, forKey: "messageUID")
            dictionary = self.messagesFetcher.preloadCellData(to: dictionary, isGroupChat: self.isGroupChat)
            let message = Message(dictionary: dictionary)
            self.messagesFetcher.loadUserNameForOneMessage(message: message, completion: { (_, newMessage)  in
                self.previousMessages.append(newMessage)
                self.loadingGroup.leave()
            })
        })
    }
    
    fileprivate func notifyWhenGroupFinished(query: DatabaseQuery) {
        loadingGroup.notify(queue: DispatchQueue.main, execute: {
            let updatedMessages = self.previousMessages + self.messages
            //   updatedMessages = self.messagesFetcher.configureTails(for: updatedMessages, isGroupChat: self.isGroupChat)
            query.removeObserver(withHandle: self.userMessageHande)
            //   print(self.previousMessages.count)
            var indexPaths = [IndexPath]()
            Array(0..<self.previousMessages.count).forEach({ (index) in
                indexPaths.append(IndexPath(item: index, section: 0))
            })
            self.delegate?.chatLogHistory(updated: updatedMessages, at: indexPaths)
        })
    }
}*/
