//
//  ChatEmptyState.swift
//  anansi
//
//  Created by João Nuno Gaspar Apura on 06/02/2018.
//  Copyright © 2018 João Apura. All rights reserved.
//

import UIKit

protocol ChatEmptyStateDelegate: class {
    func wave()
}

class ChatEmptyState: UIView {
    
    weak var delegate: ChatEmptyStateDelegate?
    
    var topbarHeight : CGFloat!
    
    var user: User? {
        didSet {
            
            // Sets my profile image
            if let myProfileImage = userDefaults.string(for: userInfoType.profileImageURL.rawValue) {
                myImage.setImage(with: myProfileImage)
            } else {
                myImage.image = UIImage(named: "profileImageTemplate")!.withRenderingMode(.alwaysOriginal)
            }
            
            // Sets conversation starter
            let firstname = user!.firstname
            let CTA : [String] = ["This could be the start of a meaningful conversation with \(firstname).",
                                  "Don't be afraid to share your ideas with \(firstname).",
                                  "Type. Send. That easy!",
                                  "What shall you say to \(firstname)?",
                                  "You're here! The day just got better for \(firstname).",
                                  "Be cool. But also be warm.",
                                  "Alright, time for meaningful discussions!"]
            
            messageLabel.text = CTA[Int.random(in: 0 ..< CTA.count)]
        }
    }
    
    let joinedImages: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    let myImage: UIImageView = {
        let i = UIImageView()
        i.image = UIImage(named: "profileImageTemplate")!.withRenderingMode(.alwaysOriginal)
        i.backgroundColor = .background
        i.contentMode = .scaleAspectFill
        i.layer.cornerRadius = 56.0 / 2
        i.layer.borderWidth = 2.0
        i.layer.borderColor = UIColor.background.cgColor
        i.layer.masksToBounds = true
        i.clipsToBounds = true
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()
    
    let userImage: UIImageView = {
        let i = UIImageView()
        i.backgroundColor = .background
        i.contentMode = .scaleAspectFill
        i.layer.cornerRadius = 52.0 / 2
        i.clipsToBounds = true
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()
    
    let messageLabel: UILabel = {
        let l = UILabel()
        l.textColor = UIColor.secondary.withAlphaComponent(0.5)
        l.numberOfLines = 0
        l.textAlignment = .center
        l.font = UIFont.systemFont(ofSize: Const.subheadFontSize)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    let waveHandEmoji: UILabel = {
        let l = UILabel()
        l.text = "👋"
        l.textAlignment = .center
        l.font = UIFont.systemFont(ofSize: 56.0)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    lazy var waveButton: UIButton = {
        let b = UIButton()
        b.setTitle("Say hi!", for: .normal)
        b.titleLabel?.textAlignment = .center
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: Const.calloutFontSize)
        b.tintColor = .white
        b.backgroundColor = .primary
        b.layer.cornerRadius = 18
        b.layer.masksToBounds = true
        b.addTarget(self, action: #selector(sendWave), for: .touchUpInside)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Grabs topbar height from parent view
        topbarHeight = frame.minY
        
        backgroundColor = .background
        
        // Add subviews
        [userImage, myImage].forEach { joinedImages.addSubview($0) }
        [joinedImages, messageLabel, waveHandEmoji, waveButton].forEach { addSubview($0) }
        
        // Add layout constraints
        setupLayoutConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        
        if let img = user?.getValue(forField: .profileImageURL) as? String {
            userImage.setImage(with: img)
        } else {
            userImage.image = UIImage(named: "profileImageTemplate")!.withRenderingMode(.alwaysOriginal)
        }
    }
    
    private func setupLayoutConstraints() {
        
        NSLayoutConstraint.activate([
            
            joinedImages.topAnchor.constraint(equalTo: topAnchor, constant: topbarHeight + Const.marginSafeArea),
            joinedImages.centerXAnchor.constraint(equalTo: centerXAnchor),
            joinedImages.heightAnchor.constraint(equalToConstant: 56.0),
            joinedImages.widthAnchor.constraint(equalToConstant: 90.0),
            
            userImage.centerYAnchor.constraint(equalTo: joinedImages.centerYAnchor),
            userImage.leadingAnchor.constraint(equalTo: joinedImages.leadingAnchor),
            userImage.widthAnchor.constraint(equalToConstant: 52.0),
            userImage.heightAnchor.constraint(equalToConstant: 52.0),
            
            myImage.centerYAnchor.constraint(equalTo: joinedImages.centerYAnchor),
            myImage.trailingAnchor.constraint(equalTo: joinedImages.trailingAnchor),
            myImage.widthAnchor.constraint(equalToConstant: 56.0),
            myImage.heightAnchor.constraint(equalToConstant: 56.0),

            messageLabel.topAnchor.constraint(equalTo: joinedImages.bottomAnchor, constant: Const.marginSafeArea),
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.widthAnchor.constraint(equalTo: widthAnchor, constant: -Const.marginSafeArea * 4.0),
            
            waveHandEmoji.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: Const.marginEight * 2.0),
            waveHandEmoji.centerXAnchor.constraint(equalTo: centerXAnchor),
            waveHandEmoji.widthAnchor.constraint(equalTo: widthAnchor),
            waveHandEmoji.heightAnchor.constraint(equalToConstant: 64.0),
            
            waveButton.topAnchor.constraint(equalTo: waveHandEmoji.bottomAnchor, constant: Const.marginEight * 2.0),
            waveButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            waveButton.widthAnchor.constraint(equalToConstant: 88.0),
            waveButton.heightAnchor.constraint(equalToConstant: 36.0),
        ])
    }
    
    @objc func sendWave() {
        delegate?.wave()
    }
}
