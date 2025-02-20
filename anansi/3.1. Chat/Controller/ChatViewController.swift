//
//  ChatViewController.swift
//  anansi
//
//  Created by João Nuno Gaspar Apura on 12/06/2019.
//  Copyright © 2019 João Apura. All rights reserved.
//

import UIKit

class ChatViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    //var isOnPage = false
    var cameFromUserProfile = false
    
    var isScrollViewAtTheBottom = false
    
    var hasBeenBlocked = false {
        didSet {
            if chatEmptyState != nil {
                chatEmptyState.messageLabel.isHidden = hasBeenBlocked
                chatEmptyState.waveHandEmoji.isHidden = hasBeenBlocked
                chatEmptyState.waveButton.isHidden = hasBeenBlocked
                
                chatAccessoryView.isHidden = hasBeenBlocked
            }
        }
    }
    
    var chatEmptyState : ChatEmptyState!
    
    var dates = [String]()
    var listOfMessagesPerDate = [String : [Message]]()
    
    var activeIndexPath: IndexPath! // when user long-presses a message
    
    private var localTyping = false
    private var partnerIsTyping = false
    
    var firstname : String = "..."
    var user: User
    var allMessages: [Message]
    
    let myID = NetworkManager.shared.getUID()
    
    // TitleLabelView
    
    lazy var userImageView : UIImageView = {
        let i = UIImageView()
        i.backgroundColor = .background
        i.contentMode = .scaleAspectFill
        i.layer.cornerRadius = 14.0
        i.clipsToBounds = true
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()
    
    lazy var userNameLabel : UILabel = {
        let l = UILabel()
        l.textColor = .secondary
        l.font = UIFont.boldSystemFont(ofSize: Const.bodyFontSize)
        l.backgroundColor = .clear
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    lazy var titleLabelView : UIStackView = {
        let sv = UIStackView(arrangedSubviews: [userImageView, userNameLabel])
        sv.axis = .horizontal
        sv.distribution = .equalSpacing
        sv.alignment = .fill
        sv.backgroundColor = .clear
        sv.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showsUserProfilePage)))
        sv.isUserInteractionEnabled = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    // Accessory view
    
    override var inputAccessoryView: ChatAccessoryView { return chatAccessoryView }
    override var canBecomeFirstResponder: Bool { return true }
    
    private lazy var chatAccessoryView: ChatAccessoryView = {
        let cv = ChatAccessoryView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 60.0))
        cv.delegate = self
        return cv
    }()
    
    // NavBar
    
    lazy var topbar: TopBar = {
        let b = TopBar()
        b.setTitle(name: "")
        b.backgroundColor = .background
        b.alpha(with: 1.0)
        b.titleLabel.alpha = 0.0
        b.bottomLine.alpha = 0.0
        b.backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        b.setActionButton(with: UIImage(named: "info")!.withRenderingMode(.alwaysTemplate))
        b.actionButton.addTarget(self, action: #selector(showActionSheet), for: .touchUpInside)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // Disconnection
    
    lazy var disconnectedView : UILabel = {
        let v = UILabel()
        v.text = "No internet connection"
        v.textColor = .background
        v.font = UIFont.boldSystemFont(ofSize: 14.0)
        v.textAlignment = .center
        v.backgroundColor = .primary
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    let statusBarHeight : CGFloat = UIApplication.shared.statusBarFrame.height
    
    // Fetcher helpers for pagination
    
    let messagesToLoad : Int = 20
    var canRefresh = false
    //var messagesFetcher: MessagesFetcher!
    //let chatHistoryFetcher = ChatHistoryFetcher()
    
    var refreshControl: UIRefreshControl = {
        var r = UIRefreshControl()
        r.tintColor = .primary
        r.backgroundColor = .clear
        //r.addTarget(self, action: #selector(performRefresh), for: .valueChanged)
        return r
    }()
    
    
    // MARK: - Init
    
    init(user: User, messages: [Message]) {
        self.user = user
        self.allMessages = messages
        
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = CGSize(width: UIScreen.main.bounds.width, height: 1.0)
        //layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        //layout.sectionInsetReference = .fromLayoutMargins
        layout.scrollDirection = .vertical
        super.init(collectionViewLayout: layout)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.collectionView.backgroundColor = .background
        self.collectionView.register(ChatMessageCell.self, forCellWithReuseIdentifier: "ChatCell")
        self.collectionView.register(StickerMessageCell.self, forCellWithReuseIdentifier: "StickerCell")
        self.collectionView.register(TypingMessageCell.self, forCellWithReuseIdentifier: "TypingCell")
        self.collectionView.register(ChatHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ChatHeader")
        self.collectionView.registerClass(revealableViewClass: TimestampView.self, forRevealableViewReuseIdentifier: "RevealableTimestamp")
        
        self.collectionView.alwaysBounceVertical = true // need to add animation to prevent bouncing when content height < view height
        self.collectionView.isDirectionalLockEnabled = true
        self.collectionView.isPrefetchingEnabled = true
        
        // Adapt collectionView contentInset to account for the navbar
        self.collectionView.contentInset.top = Const.barHeight
        self.collectionView.scrollIndicatorInsets.top = Const.barHeight
        
        // Sets up navbar
        [disconnectedView, topbar, titleLabelView].forEach { view.addSubview($0) }
        titleLabelView.setCustomSpacing(Const.marginEight, after: userImageView)
        
        // Do any additional setup after loading the view.
        setUser()
        setMessages()
        
        // Delegates
        //chatHistoryFetcher.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set up observers for messages
        DispatchQueue.global(qos: .default).async { [unowned self] in
            self.observeMessages()
        }
        
        // Handles network connectivity
        startMonitorConnectivity()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 0. Set isOnPage as true
        //isOnPage = true
        
        // 1. Setup keyboard observers
        if !hasBeenBlocked {
            setupKeyboardObservers()
        }

        // 2. Automatically presents keyboard if there's no message
        if dates.isEmpty {
            chatAccessoryView.inputTextView.becomeFirstResponder()
            
        // 3. If there're messages, mark them as Read
        } else {
            
            // Adds keyboard dismiss mode
            self.collectionView.keyboardDismissMode = .interactive
            
            // Silently resigns keyboard
            UIView.performWithoutAnimation {
                self.chatAccessoryView.inputTextView.resignFirstResponder()
            }
            
            // Re-factor to something else like "markMessagesAsRead"
            let allMessages = listOfMessagesPerDate.flatMap { $1 }
            markAsRead(messages: allMessages)
            
            // Set up observers for istyping (I need this to fire after viewDidLayoutSubviews, otherwise the layout & animation will be very messy)
            DispatchQueue.global(qos: .default).async { [unowned self] in
                self.observeTyping()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Remove keyboard observers
        removeKeyboardObservers()
        
        // Remove database observers
        if isMovingFromParent {
            
            // Message added/changed/removed
            let partnerID = user.getValue(forField: .id) as! String
            let chatID = NetworkManager.shared.childNode(myID!, partnerID)
            NetworkManager.shared.removeObserversForConversation(withID: chatID)
            
            // isTyping observer
            NetworkManager.shared.removeObserverTypingInstance(from: partnerID)
            
            // Handles network connectivity
            stopMonitorConnectivity()
        }
    }
    
    deinit {
        print("ChatViewController: Memory is freeee")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
        
        // Resigns first responder for inputTextView
        chatAccessoryView.inputTextView.resignFirstResponder()
        
        // Set isTyping to false
        isTyping = false
        
        // Set isOnPage as false
        //isOnPage = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: Layout
    private var didLayoutFlag: Bool = false
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard let collectionView = collectionView, !didLayoutFlag else { return }
        
        // Navbar
        topbar.setStatusBarHeight(with: statusBarHeight)
        topbar.setNavigationBarHeight(with: Const.barHeight)
        
        NSLayoutConstraint.activate([
            
            topbar.topAnchor.constraint(equalTo: view.topAnchor),
            topbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topbar.heightAnchor.constraint(equalToConstant: Const.barHeight + statusBarHeight),
            
            userImageView.centerYAnchor.constraint(equalTo: topbar.navigationbar.centerYAnchor),
            userImageView.leadingAnchor.constraint(equalTo: topbar.backButton.trailingAnchor, constant: Const.marginEight * 2.0),
            userImageView.widthAnchor.constraint(equalToConstant: 28.0),
            userImageView.heightAnchor.constraint(equalToConstant: 28.0),
            
            userNameLabel.centerYAnchor.constraint(equalTo: userImageView.centerYAnchor),
            
            disconnectedView.topAnchor.constraint(equalTo: topbar.bottomAnchor, constant: -32.0),
            disconnectedView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            disconnectedView.widthAnchor.constraint(equalTo: view.widthAnchor),
            disconnectedView.heightAnchor.constraint(equalToConstant: 32.0),
        ])

        // This shows the list of messages starting from the last message
        if !dates.isEmpty {
            
            UIView.performWithoutAnimation {
                if collectionView.contentSize.height < collectionView.bounds.height {
                    collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
                    
                } else {
                    let contentOffset = CGPoint(x: 0.0, y: collectionView.contentSize.height - (collectionView.bounds.size.height - chatAccessoryView.frame.height))
                    collectionView.setContentOffset(contentOffset, animated: false)
                }
            }
            
            isScrollViewAtTheBottom = true
        }
        
        // Refresh control
        collectionView.refreshControl = canRefresh && allMessages.count >= messagesToLoad ? refreshControl : nil
        
        didLayoutFlag = true
    }
}

    
// MARK: UICollectionViewDataSource

extension ChatViewController {
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        if dates.isEmpty {
            chatEmptyState = ChatEmptyState(frame: CGRect(x: 0, y: Const.barHeight + statusBarHeight, width: collectionView.bounds.size.width, height: collectionView.bounds.size.height))
            chatEmptyState.user = user
            chatEmptyState.delegate = self
            
            collectionView.backgroundView = chatEmptyState
            return 0
            
        } else {
            collectionView.backgroundView = nil
            return dates.count
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let dateString = dates[section]
        return listOfMessagesPerDate[dateString]!.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let lastsection = dates.count - 1
        let lastitem = listOfMessagesPerDate[dates[lastsection]]!.count - 1
        
        if partnerIsTyping,
            indexPath.section == lastsection && indexPath.item == lastitem {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TypingCell", for: indexPath) as! TypingMessageCell
            cell.indexPath = indexPath
            cell.config()
            
            return cell
            
        } else {
            
            // Get all the info needed
            let date = dates[indexPath.section]
            let message = listOfMessagesPerDate[date]![indexPath.item]
            let usrimg = user.getValue(forField: .profileImageURL) as? String ?? ""
            
            let isIncoming = ((message.getValue(forField: .sender) as? String) != myID!)
            let showStatus = !isIncoming ? ((!partnerIsTyping && indexPath.section == lastsection && indexPath.item == lastitem) || (partnerIsTyping && indexPath.section == lastsection && indexPath.item == lastitem - 1)) : false
            
            // Determines which type is required
            if (message.getValue(forField: .text) as? String) == Const.stickerString {
                
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StickerCell", for: indexPath) as! StickerMessageCell
                cell.gestureRecognizerDelegate = self
                cell.indexPath = indexPath
                cell.config(message: message, isIncoming: isIncoming, showStatus: showStatus, with: usrimg)
                
                if let view = collectionView.dequeueReusableRevealableView(withIdentifier: "RevealableTimestamp") as? TimestampView {
                    let tstamp = NSDate(timeIntervalSince1970: (message.getValue(forField: .timestamp) as! NSNumber).doubleValue)
                    view.timestamp.text = getTimeString(from: tstamp)
                    view.setConstraints(with: !cell.reactionStackView.isHidden, and: isIncoming)
                    
                    let style: RevealStyle = isIncoming ? .over : .slide
                    cell.setRevealableView(view, style: style, direction: .left)
                }
                
                return cell
                
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ChatCell", for: indexPath) as! ChatMessageCell
                cell.gestureRecognizerDelegate = self
                cell.indexPath = indexPath
                cell.config(message: message, isIncoming: isIncoming, showStatus: showStatus, with: usrimg)
                
                if let view = collectionView.dequeueReusableRevealableView(withIdentifier: "RevealableTimestamp") as? TimestampView {
                    let tstamp = NSDate(timeIntervalSince1970: (message.getValue(forField: .timestamp) as! NSNumber).doubleValue)
                    view.timestamp.text = getTimeString(from: tstamp)
                    view.setConstraints(with: !cell.reactionStackView.isHidden, and: isIncoming)
                    
                    let style: RevealStyle = isIncoming ? .over : .slide
                    cell.setRevealableView(view, style: style, direction: .left)
                }
                
                return cell
            }
        }
    }
    
    /// This draws the scrollbar above headers and footers for UICollectionViewControllers
    override open func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        view.layer.zPosition = -1
    }
    
    // This handles the headers
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        let firstMessageInSection = listOfMessagesPerDate[dates[indexPath.section]]?.first
        let timestampSec = (firstMessageInSection!.getValue(forField: .timestamp) as! NSNumber).doubleValue
        let currentMsgDate = NSDate(timeIntervalSince1970: timestampSec)
        
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "ChatHeader", for: indexPath) as? ChatHeaderView
                else { fatalError("Invalid view type") }
            header.config(withLabel: timestring(from: currentMsgDate))
            
            return header
            
        default:
            preconditionFailure("Invalid supplementary view type for this collection view")
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout

    /// The code seems repetitive (given cellForItemAt), but this is necessary to properly size the items
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let lastsection = dates.count - 1
        let lastitem = listOfMessagesPerDate[dates[lastsection]]!.count - 1
        
        let date = dates[indexPath.section]
        let message = listOfMessagesPerDate[date]![indexPath.item]
        
        let isIncoming = ((message.getValue(forField: .sender) as? String) != myID!)
        let showStatus = !isIncoming ? ((!partnerIsTyping && indexPath.section == lastsection && indexPath.item == lastitem) || (partnerIsTyping && indexPath.section == lastsection && indexPath.item == lastitem - 1)) : false
        
        var height : CGFloat
        
        if partnerIsTyping,
            indexPath.section == lastsection && indexPath.item == lastitem {
            
            let estimatedCell = TypingMessageCell()
            estimatedCell.config()
            estimatedCell.layoutIfNeeded()
            height = estimatedCell.systemLayoutSizeFitting(.init(width: view.frame.width, height: 1000)).height
            
        } else {
            
            if (message.getValue(forField: .text) as? String) == Const.stickerString {
                
                let estimatedCell = StickerMessageCell()
                estimatedCell.config(message: message, isIncoming: isIncoming, showStatus: showStatus, with: "")
                estimatedCell.layoutIfNeeded()
                height = estimatedCell.systemLayoutSizeFitting(.init(width: view.frame.width, height: 1000)).height
                
            } else {
                
                let estimatedCell = ChatMessageCell()
                estimatedCell.config(message: message, isIncoming: isIncoming, showStatus: showStatus, with: "")
                estimatedCell.layoutIfNeeded()
                height = estimatedCell.systemLayoutSizeFitting(.init(width: view.frame.width, height: 1000)).height
            }
        }
        
        return CGSize(width: view.frame.width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: view.frame.width, height: 32.0)
    }
    
    // This determines spacing between items & between sections and items
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
}

// MARK: - Custom functions

extension ChatViewController {
    
    func setUser() {
        
        // Extract first name
        chatAccessoryView.placeholderText = "Message \(user.firstname)"
        
        // User information in navigation bar
        userNameLabel.text = (user.getValue(forField: .name) as? String)!
        if let userImage = user.getValue(forField: .profileImageURL) as? String {
            userImageView.setImage(with: userImage)
        } else {
            userImageView.image = UIImage(named: "profileImageTemplate")!.withRenderingMode(.alwaysOriginal)
        }
        
        // Hides chatAcessoryView if user is blocked
        if let blockedDic = user.getValue(forField: .blockedUsers) as? [String: String] {
            
            if blockedDic.index(forKey: myID!) != nil {
                hasBeenBlocked = true
            }
        }
    }
    
    func setMessages() {
        
        if !allMessages.isEmpty {
            for message in allMessages {
                
                let timestamp = message.getValue(forField: .timestamp) as! NSNumber
                let dateString = createDateIntervalStringForMessage(from: NSDate(timeIntervalSince1970: timestamp.doubleValue))
                
                if !(dates.contains(dateString)) {
                    dates.append(dateString)
                    listOfMessagesPerDate[dateString] = [message]
                } else {
                    listOfMessagesPerDate[dateString]!.append(message)
                }
            }
        }
    }
    
    func markAsRead(messages: [Message]) {
        
        for message in messages {
            
            // If I'm the receiver && !isRead
            if let receiver = message.getValue(forField: .receiver) as? String,
                receiver == self.myID!,
                let isRead = message.getValue(forField: .isRead) as? Bool,
                !isRead {
                
                NetworkManager.shared.markMessagesAs(messageInfoType.isRead.rawValue, withID: message.getValue(forField: .id) as! String, from: message.getValue(forField: .sender) as! String, to: myID!, onSuccess: nil)
            }
        }
    }
    
    // MARK: - Keyboard-related functions
    
    func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(adjustKeyboard), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adjustKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func adjustKeyboard(notification: NSNotification) {
        
        // guard let userInfo = notification.userInfo else { return }
        // guard let keyboardEndFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        //
        // NOTE: KeyboardEndFrame
        //           - includes inputAccessoryView when shown (59.3333)
        //           - includes inputAccessoryView and view.safeAreaInsets.bottom when hidden (59.3333 + 34.0 = 93.3333)
        // let keyboardHeight = keyboardEndFrame.height - inputAccessoryView.frame.height //- view.safeAreaInsets.bottom
        
        // If scrollView is at the bottom & keyboard will show, then scroll to bottom of collectionView
        if !dates.isEmpty && isScrollViewAtTheBottom && (notification.name == UIResponder.keyboardWillShowNotification) {
            DispatchQueue.main.async { self.collectionView.scrollToBottom(at: .top) }
        }
    }
    
    @objc override func dismissKeyboard() {
        chatAccessoryView.inputTextView.resignFirstResponder()
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        guard let contentOffsetY = collectionView?.contentOffset.y else { return }
        guard let contentHeight = collectionView?.contentSize.height else { return }
        guard let frameHeight = collectionView?.frame.size.height else { return }
        
        // Set isScrollViewAtTheBottom boolean
        isScrollViewAtTheBottom = contentOffsetY >= (contentHeight - frameHeight - 200) // 200 margin might be enough
        print(isScrollViewAtTheBottom)
        
        // Pagination should be implemented here
        if scrollView.contentOffset.y < 0 {
            
            if contentHeight < UIScreen.main.bounds.height - chatAccessoryView.inputTextView.frame.height {
                canRefresh = false
            }
            
            if canRefresh && !refreshControl.isRefreshing {
                canRefresh = false
                performRefresh()
            }
            
            // End refreshControl animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshControl.endRefreshing()
            }
            
        } else if scrollView.contentOffset.y >= 0 {
            canRefresh = true
        }
    }
    
    
    // MARK: - Actions
    
    @objc func showsUserProfilePage() {
        
        if cameFromUserProfile {
            navigationController?.popViewController(animated: true)
            
        } else {
            let controller = UserPageViewController(user: user)
            controller.cameFromChat = true
            navigationController?.pushViewController(controller, animated: true)
        }
    }
    
    @objc func showActionSheet() {
        // TO DO: add other functionalities, like sharing contact, etc
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.view.tintColor = UIColor.init(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0) // Apple's blue?
        
        let contactDetails = UIAlertAction(title: "Contact details", style: .default, handler: { (action) -> Void in
            
            self.showsUserProfilePage()
        })
        alertController.addAction(contactDetails)
        
        // Only show report abuse if hasn't been blocked already
        if !hasBeenBlocked {
            let reportUser = UIAlertAction(title: "Report abuse", style: .destructive, handler: { (action) -> Void in
                
                let controller = ReportAbuseViewController()
                controller.delegate = self
                controller.user = self.user
                
                self.navigationController?.navigationBar.isTranslucent = true
                self.navigationController?.pushViewController(controller, animated: true)
            })
            alertController.addAction(reportUser)
        }
        
        let deleteChat = UIAlertAction(title: "Delete conversation", style: .destructive, handler: { (action) -> Void in
            
            if let userID = self.user.getValue(forField: .id) as? String {
                
                NetworkManager.shared.deleteUserMessageNode(from: self.myID!, to: userID, onDelete: { [weak self] in self?.back() })
            }
        })
        // Handles disconnection
        if ConnectionManager.shared.currentConnectivityStatus != .disconnected { alertController.addAction(deleteChat) }
        
        // Dismiss alertController
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelButton)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @objc func back() {
        navigationController?.popViewController(animated: true)
    }
    
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            let myID = NetworkManager.shared.getUID()
            
            if newValue {
                let receiverID = (user.getValue(forField: .id) as? String)!
                NetworkManager.shared.createTypingInstance(from: myID!, to: receiverID, onSucess: nil)
            } else {
                NetworkManager.shared.removeTypingInstance(from: myID!, onSucess: nil)
            }
        }
    }
    
    func observeTyping() {
        
        let receiverID = (user.getValue(forField: .id) as? String)!
        
        NetworkManager.shared.observeTypingInstances(from: receiverID,
            onTyping: { [weak self] (partnerID) in
                guard let self = self else { return }
                
                if partnerID == self.myID {
                    
                    self.partnerIsTyping = true
                    
                    let lastsection = self.dates.count - 1
                    let typingMessage = Message(dictionary: [:], messageID: "typingMessage")
                    self.listOfMessagesPerDate[self.dates[lastsection]]!.append(typingMessage)
                    
                    // Insert new item in collectionView
                    self.collectionView.performBatchUpdates({
                        let item = self.listOfMessagesPerDate[self.dates[lastsection]]!.count - 1
                        self.collectionView.insertItems(at: [IndexPath(item: item, section: lastsection)])
                    }, completion: { (true) in
                        self.collectionView.layoutIfNeeded()
                    })
                    
                    if self.isScrollViewAtTheBottom {
                        self.collectionView.scrollToBottom(at: .bottom)
                    }
                }
            
            }, onNotTyping: { [weak self] in
                guard let self = self else { return }
                
                if self.partnerIsTyping {
                    
                    self.partnerIsTyping = false
                    
                    let lastsection = self.dates.count - 1
                    let lastitem = self.listOfMessagesPerDate[self.dates[lastsection]]!.count - 1
                    let lastMessageFromLastSection = self.listOfMessagesPerDate[self.dates[lastsection]]![lastitem]
                    
                    if (lastMessageFromLastSection.getValue(forField: .id) as! String) == "typingMessage" {
                        self.listOfMessagesPerDate[self.dates[lastsection]]!.removeLast()
                    }
                    
                    // Remove item in collectionView
                    self.collectionView.performBatchUpdates({
                        self.collectionView.deleteItems(at: [IndexPath(item: lastitem, section: lastsection)])
                    }, completion: { (true) in
                        self.collectionView.layoutIfNeeded()
                    })
                }
            })
    }
}

// MARK: - UserWasReported

extension ChatViewController: UserWasReported {
    
    func userWasReported(user: User) {
        
        let controller = ReportConfirmationView()
        controller.user = user
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        
        present(controller, animated: true, completion: nil)
    }
}

// MARK: - ChatAccessoryDelegate

extension ChatViewController: ChatAccessoryDelegate {
    
    func sendMessage(message: String) {
        
        sendMessageWith(string: message)
        
        chatAccessoryView.inputTextView.text = nil
        chatAccessoryView.inputTextView.placeholder = "Message \(user.firstname)"
        isTyping = false
        
        collectionView.scrollToBottom(at: .top)
    }
    
    func isTypingMessage(value: Bool) {
        isTyping = value
    }
    
    private func sendMessageWith(string: String) {
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let currentTime = formatter.string(from: Date())
        
        let myID = NetworkManager.shared.getUID()
        let userID = user.getValue(forField: .id) as! String
        
        let message : [String: Any] = [messageInfoType.timestamp.rawValue: currentTime, messageInfoType.text.rawValue: string, messageInfoType.isSent.rawValue: "false", messageInfoType.isDelivered.rawValue: "false", messageInfoType.isRead.rawValue: "false", messageInfoType.sender.rawValue: myID!, messageInfoType.receiver.rawValue: userID]
        
        NetworkManager.shared.postChatMessageInDB(sender: myID!, receiver: userID, message: message, onSuccess: nil)
    }
}

// MARK: - ChatEmptyStateDelegate

extension ChatViewController: ChatEmptyStateDelegate {
    
    func wave() {
        sendMessageWith(string: "👋")
    }
}

// MARK: - CellGestureRecognizerDelegate

extension ChatViewController: CellGestureRecognizerDelegate {
    
    func singleTapDetected(in indexPath: IndexPath) {
        // Nothing here (not implemented in ChatMessageCell)
    }
    
    func doubleTapDetected(in indexPath: IndexPath, with message: Message, and love: Bool) {
        
        activeIndexPath = indexPath
        
        let msgID = message.getValue(forField: .id) as? String
        let sender = message.getValue(forField: .sender) as? String
        let receiver = message.getValue(forField: .receiver) as? String
        
        if love {
            NetworkManager.shared.registerReaction("heart", for: msgID!, to: sender!, from: receiver!) {
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        } else {
            NetworkManager.shared.removeReaction("heart", for: msgID!, to: sender!, from: receiver!) {
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }
    
    // Long press shows an alert controller with some functionalities, such as copy, unsend, etc
    func longPressDetected(in indexPath: IndexPath, with message: Message, from sender: UILongPressGestureRecognizer) {
        
        becomeFirstResponder()
        
        activeIndexPath = indexPath
        
        let isConnected = ConnectionManager.shared.currentConnectivityStatus == .connected // Handles disconnection
        let receiver = message.getValue(forField: .receiver) as? String
        let isSent = message.getValue(forField: .isSent) as! Bool
        
        let copy = UIMenuItem(title: "Copy", action: #selector(copytxt(_:)))
        let deleteTxt = UIMenuItem(title: "Unsend", action: #selector(unsendTxt(_:)))
        let deleteSticker = UIMenuItem(title: "Unsend", action: #selector(unsendSticker(_:)))
        let menu = UIMenuController.shared
        
        if let cell = self.collectionView.cellForItem(at: indexPath) as? ChatMessageCell {
            menu.menuItems = (myID == receiver) ? [copy] : (isSent && isConnected ? [copy, deleteTxt] : [copy] )
            menu.setTargetRect(sender.view!.frame, in: cell)
            
        } else {
            menu.menuItems = (myID == receiver) ? [] : (isSent && isConnected ? [deleteSticker] : [])
            menu.setTargetRect(sender.view!.frame, in: self.collectionView.cellForItem(at: indexPath) as! StickerMessageCell)
        }
        menu.setMenuVisible(true, animated: true)
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copytxt(_:)) {
            return true
        } else if action == #selector(unsendTxt(_:)) {
            return true
        } else if action == #selector(unsendSticker(_:)) {
            return true
        }
        return false
    }
    
    @objc func copytxt(_ sender: Any?) {
        
        let cell = self.collectionView.cellForItem(at: activeIndexPath) as! ChatMessageCell
        if let txt = cell.message!.getValue(forField: .text) as? String {
            UIPasteboard.general.string = txt
        }
    }
    
    @objc func unsendTxt(_ sender: Any?) {
        
        let cell = self.collectionView.cellForItem(at: activeIndexPath) as! ChatMessageCell
        if let msg = cell.message {
            unsend(message: msg)
        }
    }
    
    @objc func unsendSticker(_ sender: Any?) {
        
        let cell = self.collectionView.cellForItem(at: activeIndexPath) as! StickerMessageCell
        if let msg = cell.message {
            unsend(message: msg)
        }
    }
    
    func unsend(message: Message) {
        
        let msgID = message.getValue(forField: .id) as! String
        let sender = message.getValue(forField: .sender) as! String
        let receiver = message.getValue(forField: .receiver) as! String
        
        NetworkManager.shared.deleteMessage(with: msgID, from: sender, to: receiver, onDelete: nil)
    }
}

// MARK: - Fetching messages

extension ChatViewController {
    
    @objc func performRefresh() {
        
        let partnerID = user.getValue(forField: .id) as! String
        let chatID = NetworkManager.shared.childNode(myID!, partnerID)
        
        // Should I do anything here re: refreshControl?
        // collectionView.refreshControl = canRefresh && allMessages.count >= messagesToLoad ? refreshControl : nil

        print("Performing refresh")
        //chatLogHistoryFetcher.loadPreviousMessages(messages, conversation, messagesToLoad, true)
    }
}

/*
extension ChatViewController: ChatHistoryDelegate {
    
    func chatHistory(isEmpty: Bool) {
        refreshControl.endRefreshing()
    }
    
    func chatHistory(updated messages: [Message], at indexPaths: [IndexPath]) {
        //contentSize = collectionView?.contentSize
        refreshControl.endRefreshing()
        
        //self.messages = messages
        
        UIView.performWithoutAnimation {
            collectionView?.performBatchUpdates ({
                collectionView?.insertItems(at: indexPaths)
            }, completion: nil)
        }
    }
}*/

// MARK: - NetworkManager

extension ChatViewController {
    
    private func observeMessages() {
        
        let partnerID = user.getValue(forField: .id) as! String
        let chatID = NetworkManager.shared.childNode(myID!, partnerID)
        
        // If there're conversations in Firebase
        NetworkManager.shared.observeConversation(withID: chatID, onAdd: { [weak self] (mesg, msgID) in
            guard let self = self else { return }
            
            let message = Message(dictionary: mesg, messageID: msgID)
            
            if let timestamp = message.getValue(forField: .timestamp) as? NSNumber {
                let dateString = createDateIntervalStringForMessage(from: NSDate(timeIntervalSince1970: timestamp.doubleValue))
                
                if !(self.dates.contains(dateString)) {
                    self.dates.append(dateString)
                    self.listOfMessagesPerDate[dateString] = [message]
                    
                    // Insert new item in collectionView
                    self.collectionView.performBatchUpdates({
                        let lastSection = self.dates.count - 1
                        let lastItem = self.listOfMessagesPerDate[dateString]!.count - 1
                        
                        self.collectionView.insertSections(IndexSet(integer: lastSection))
                        self.collectionView.insertItems(at: [IndexPath(item: lastItem, section: lastSection)])
                        
                    }, completion: { (true) in
                        self.collectionView.layoutIfNeeded()
                    })

                } else {
                    
                    // this is necessary, because I'm sending all my messages from ConnectViewController here and I don't want duplicates
                    let messageKeysForDate = self.listOfMessagesPerDate[dateString]!.map { $0.getValue(forField: .id) as! String }
                    if !messageKeysForDate.contains(msgID) {
                        self.listOfMessagesPerDate[dateString]!.append(message)
                        
                        // Insert new item in collectionView
                        self.collectionView.performBatchUpdates({
                            let section = self.dates.index(of: dateString)!
                            let lastItem = self.listOfMessagesPerDate[dateString]!.count - 1
                            self.collectionView.insertItems(at: [IndexPath(item: lastItem, section: section)])
                            
                        }, completion: { (true) in
                            self.collectionView.layoutIfNeeded()
                        })
                    }
                }
                
                // If user is at the bottom of collectionView, then we need to mark any incoming message as read
                if self.isScrollViewAtTheBottom {
                    self.collectionView.scrollToBottom(at: .top)
                    self.markAsRead(messages: [message]) // Do I need this here?
                    
                } else {
                    
                    // TO DO:
                    // Show widget to go to bottom
                    // If I tap on that widget, the collectionview is scrolled to bottom and messages are marked as read
                }
            }
            
        }, onChange: { [weak self] (mesg, msgID) in
            guard let self = self else { return }
            
            let message = Message(dictionary: mesg, messageID: msgID)
            
            let timestamp = message.getValue(forField: .timestamp) as! NSNumber
            let dateString = createDateIntervalStringForMessage(from: NSDate(timeIntervalSince1970: timestamp.doubleValue))
            
            if let chatsForDate = self.listOfMessagesPerDate[dateString] {
                for (index, element) in chatsForDate.enumerated() {
                    
                    if (element.getValue(forField: .id) as! String == msgID) {
                        self.listOfMessagesPerDate[dateString]![index] = message
                        
                        // Update item in collectionView
                        DispatchQueue.main.async {
                            
                            self.collectionView.performBatchUpdates({
                                let section = self.dates.index(of: dateString)!
                                self.collectionView.reloadItems(at: [IndexPath(item: index, section: section)])
                                
                            }, completion: { (true) in
                                self.collectionView.layoutIfNeeded()
                            })
                        }
                    }
                }
            }
            
        }, onRemove: { [weak self] (mesg, msgID) in
            guard let self = self else { return }
            
            let message = Message(dictionary: mesg, messageID: msgID)
            
            let timestamp = message.getValue(forField: .timestamp) as! NSNumber
            let dateString = createDateIntervalStringForMessage(from: NSDate(timeIntervalSince1970: timestamp.doubleValue))
            
            if let chatsForDate = self.listOfMessagesPerDate[dateString] {
                
                for (index, element) in chatsForDate.enumerated() {
                    
                    if (element.getValue(forField: .id) as! String == msgID) {
                        self.listOfMessagesPerDate[dateString]!.remove(at: index)
                        
                        // Remove item in collectionView
                        self.collectionView.performBatchUpdates({
                            let section = self.dates.index(of: dateString)!
                            self.collectionView.deleteItems(at: [IndexPath(item: index, section: section)])
                            
                        }, completion: { (true) in
                            self.collectionView.layoutIfNeeded()
                        })
                    
                    }
                    
                    if self.listOfMessagesPerDate[dateString]!.isEmpty {
                        self.listOfMessagesPerDate[dateString] = nil
                        
                        let i = self.dates.index(of: dateString)
                        self.dates.remove(at: i!)
                        
                        // Remove section in collectionView
                        self.collectionView.performBatchUpdates({
                            self.collectionView.deleteSections(IndexSet(integer: i!))
                            
                        }, completion: { (true) in
                            self.collectionView.layoutIfNeeded()
                        })
                        
                    }
                }
            }
        })
        
        // In case there's a chatID, but no messages
        // should I reload the table?s
    }
}

// MARK: - ConnectionManager

extension ChatViewController {

    func startMonitorConnectivity() {
        
        NetworkManager.shared.setOnlineObserver(onConnected: { [weak self] in
            DispatchQueue.main.async { self?.hideAlert() }
        }, onDisconnected: { [weak self] in
            DispatchQueue.main.async { self?.showAlert() }
        })
    }
    
    func stopMonitorConnectivity() {
        NetworkManager.shared.removeOnlineObserver()
    }
    
    func showAlert() {
        
        disconnectedView.isHidden = false
        
        UIView.animate(withDuration: 0.5, animations: {
            self.disconnectedView.transform = CGAffineTransform(translationX: 0, y: 32.0)
        })
    }
    
    func hideAlert() {
        
        UIView.animate(withDuration: 0.5, animations: {
            self.disconnectedView.transform = .identity
        }, completion: { (bool) in
            self.disconnectedView.isHidden = true
        })
    }
}
