//
//  UserPageViewController.swift
//  anansi
//
//  Created by João Nuno Gaspar Apura on 20/04/2019.
//  Copyright © 2019 João Apura. All rights reserved.
//

import UIKit
import SafariServices

class UserPageViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // Custom initializers
    var cameFromChat: Bool = false
    
    var sections = [String]()
    var sectionDataToDisplay = [Int : [String]]()
    var iconForContactSection = [String]()    
    var userInterests = [String]()
    var myInterests = [String]()
        
    var user: User
    
    // NavBar
    
    lazy var topbar: TopBar = {
        let b = TopBar()
        b.setTitle(name: "")
        b.backgroundColor = .clear
        b.alpha(with: 0)
        b.backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    // View
    
    lazy var scrollView : UIScrollView = {
        let sv = UIScrollView()
        sv.delegate = self
        sv.backgroundColor = .background
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let contentView : UIView = {
        let cv = UIView()
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    lazy var backgroundImage: GradientView = {
        let v = GradientView()
        v.mask = UIImageView(image: UIImage(named: "cover-users")?.withRenderingMode(.alwaysTemplate))
        v.mask?.contentMode = .scaleToFill
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    // Header
    lazy var headerView : ProfileHeader = {
        let hv = ProfileHeader()
        hv.setTitleColor(textColor: .secondary)
        hv.setBottomBorderColor(lineColor: .primary)
        hv.translatesAutoresizingMaskIntoConstraints = false
        return hv
    }()
    
    // Call-to-action view
    let callToActionView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    var callToActionViewHeightAnchor: NSLayoutConstraint?
    
    // Say hi! button
    lazy var newChatButton: PrimaryButton = {
        let b = PrimaryButton()
        b.setTitle(" Say hi!", for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: Const.bodyFontSize)
        b.setImage(UIImage(named: "wave")!.withRenderingMode(.alwaysTemplate), for: .normal)
        b.tintColor = .background
        b.translatesAutoresizingMaskIntoConstraints = false
        b.layer.cornerRadius = 20
        b.layer.masksToBounds = true
        b.addTarget(self, action: #selector(showChatLogController), for: .touchUpInside)
        return b
    }()
    
    // Table with profile data
    lazy var tableView : UIDynamicTableView = {
        let tv = UIDynamicTableView()
        tv.register(DescriptionTableViewCell.self, forCellReuseIdentifier: "AboutCell")
        tv.register(ContactInfoTableViewCell.self, forCellReuseIdentifier: "ContactCell")
        tv.register(InterestsUserTableCell.self, forCellReuseIdentifier: "InterestTableCell")
        tv.isScrollEnabled = false
        tv.delegate = self
        tv.dataSource = self
        tv.separatorStyle = .none
        tv.allowsSelection = true
        tv.sectionHeaderHeight = 56.0
        tv.estimatedSectionHeaderHeight = 56.0
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 100.0
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    let statusBarHeight : CGFloat = UIApplication.shared.statusBarFrame.height
    
    // MARK: Init
    
    init(user: User) {
        self.user = user
        super.init(nibName:nil, bundle:nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .background
        
        [scrollView, topbar].forEach { view.addSubview($0) }
        scrollView.addSubview(contentView)
        [backgroundImage, headerView, newChatButton, tableView].forEach { contentView.addSubview($0)}
        
        configUserPage()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Updates ranking
        if let id = user.getValue(forField: .id) as? String {
            NetworkManager.shared.updatesUserViews(id: id)
        }
        
        // Adds user to recently viewed
        if var recentlyViewed = userDefaults.stringList(for: userDefaults.recentlyViewedIDs) {
            
            let userID = user.getValue(forField: .id) as! String
            
            if let i = recentlyViewed.index(of: userID) { recentlyViewed.remove(at: i) }
            recentlyViewed.insert(userID, at: 0)
            userDefaults.updateObject(for: userDefaults.recentlyViewedIDs, with: recentlyViewed)
            
        } else {
            
            let userID = user.getValue(forField: .id) as! String
            userDefaults.updateObject(for: userDefaults.recentlyViewedIDs, with: [userID])
        }
    }
    
    // MARK: Layout
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        topbar.setLargerBackButton()
        topbar.setStatusBarHeight(with: statusBarHeight)
        topbar.setNavigationBarHeight(with: Const.barHeight)
        
        NSLayoutConstraint.activate([
            
            // Navbar
            
            topbar.topAnchor.constraint(equalTo: view.topAnchor),
            topbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topbar.heightAnchor.constraint(equalToConstant: Const.barHeight + statusBarHeight),
            
            // View
            
            scrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scrollView.widthAnchor.constraint(equalTo: view.widthAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            
            backgroundImage.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -statusBarHeight),
            backgroundImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundImage.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundImage.heightAnchor.constraint(equalToConstant: 374.0),
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: statusBarHeight),
            headerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            headerView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 214.0),
            
            newChatButton.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: Const.marginSafeArea),
            newChatButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Const.marginSafeArea),
            newChatButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Const.marginSafeArea),
            newChatButton.heightAnchor.constraint(equalToConstant: 40.0),
            
            tableView.topAnchor.constraint(equalTo: newChatButton.bottomAnchor, constant: Const.marginEight),
            tableView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            tableView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Const.marginEight * 4.0),
            
        ])
        
        DispatchQueue.main.async {
            
            // Sets gradients for backgroundImage
            self.backgroundImage.applyGradient(withColours: [.primary, .primary], gradientOrientation: .vertical)
            
            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()
        }
    }
        
    // MARK: Custom functions
    
    private func configUserPage() {
        
        if let profileImageURL = user.getValue(forField: .profileImageURL) as? String {
            
            headerView.profileImage.setImage(with: profileImageURL)
        } else {
            
            headerView.profileImage.image = UIImage(named: "profileImageTemplate")!.withRenderingMode(.alwaysOriginal)
        }
        
        if let name = user.getValue(forField: .name) as? String {
            topbar.setTitle(name: name)
            
            headerView.setTitleName(name: name)
            newChatButton.setTitle(" Say hi to \(user.firstname)", for: .normal)
        }
        
        if let occupation = user.getValue(forField: .occupation) as? String { headerView.setOccupation(occupation) }
        
        if let location = user.getValue(forField: .location) as? String { headerView.setLocation("From " + location) }
        
        if let bio = user.getValue(forField: .bio) as? String {
            
            sections.append("About")
            let index = sections.count - 1
            sectionDataToDisplay[index] = [bio]
        }
        
        if let interests = user.getValue(forField: .interests) as? [String] {
            
            sections.append("Let's talk about")
            let index = sections.count - 1
            sectionDataToDisplay[index] = ["interests are presented here"]
            userInterests = interests.sorted()
            
            fetchMyInterests()
        }
        
        if let title = user.getValue(forField: .tedTitle) as? String {
            
            sections.append("Favorite TED talk")
            let index = sections.count - 1
            sectionDataToDisplay[index] = [title]
        }
        
        if let email = user.getValue(forField: .sharedEmail) as? String {
            
            if !sections.contains("Let's keep in touch") { sections.append("Let's keep in touch") }
            
            let index = sections.count - 1
            
            if sectionDataToDisplay[index] == nil {
                sectionDataToDisplay[index] = [email]
            } else {
                sectionDataToDisplay[index]?.append(email)
            }
            
            iconForContactSection.append("email")
        }
        
        if let website = user.getValue(forField: .website) as? String {
            
            if !sections.contains("Let's keep in touch") { sections.append("Let's keep in touch") }
            
            let index = sections.count - 1
            
            if sectionDataToDisplay[index] == nil {
                sectionDataToDisplay[index] = [website]
            } else {
                sectionDataToDisplay[index]?.append(website)
            }
            
            iconForContactSection.append("website")
        }
        
        if let linkedin = user.getValue(forField: .linkedin) as? String {
            
            if !sections.contains("Let's keep in touch") { sections.append("Let's keep in touch") }
            
            let index = sections.count - 1
            
            if sectionDataToDisplay[index] == nil {
                sectionDataToDisplay[index] = [linkedin]
            } else {
                sectionDataToDisplay[index]?.append(linkedin)
            }
            
            iconForContactSection.append("linkedin")
        }
        
        tableView.reloadData()
    }
    
    private func fetchMyInterests() {
        
        if let interests = userDefaults.stringList(for: userInfoType.interests.rawValue) {
            myInterests = interests
        }
    }
    
    private func openURLfromStringInWebViewer(string : String) {
        
        if let url = URL(string: string) {
            
            // Open link inside the app, instead of leaving the app. Needs import SafariServices
            let vc = SFSafariViewController(url: url)
            present(vc, animated: true, completion: nil)
        }
    }
    
    private func openURLfromString(string : String) {
        
        if let url = URL(string: string) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(url)
            }
        }
    }
    
    @objc func back() {
        
        navigationController?.popViewController(animated: true)
    }
    
    @objc func showChatLogController() {
        
        if cameFromChat {            
            navigationController?.popViewController(animated: true)
            
        } else {
            
            let chatController = ChatViewController(user: user, messages: [])
            chatController.cameFromUserProfile = true
            chatController.hidesBottomBarWhenPushed = true
            
            navigationController?.pushViewController(chatController, animated: true)
        }
    }
    
    // MARK: UITableViewDelegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (sectionDataToDisplay[section]?.count)!
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let v : UIView =  {
            let v = UIView()
            v.backgroundColor = .clear
            return v
        }()
        
        let l : UILabel = {
            let l = UILabel()
            l.text = sections[section]
            l.font = UIFont.boldSystemFont(ofSize: Const.bodyFontSize)
            l.textColor = .secondary
            l.translatesAutoresizingMaskIntoConstraints = false
            return l
        }()
        
        v.addSubview(l)
        v.addConstraint(NSLayoutConstraint(item: l, attribute: .leading, relatedBy: .equal, toItem: v, attribute: .leading, multiplier: 1.0, constant: 24.0))
        v.addConstraint(NSLayoutConstraint(item: l, attribute: .trailing, relatedBy: .equal, toItem: v, attribute: .trailing, multiplier: 1.0, constant: -24.0))
        v.addConstraint(NSLayoutConstraint(item: l, attribute: .top, relatedBy: .equal, toItem: v, attribute: .top, multiplier: 1.0, constant: 24.0))
        v.addConstraint(NSLayoutConstraint(item: l, attribute: .bottom, relatedBy: .equal, toItem: v, attribute: .bottom, multiplier: 1.0, constant: 0.0))
        
        // Interests
        if sections[section] == "Let's talk about" {
            
            let countInterestsInCommon = userInterests.filter({ myInterests.contains($0) }).count
            let u : UILabel = {
                let u = UILabel()
                u.text = "\(countInterestsInCommon) shared interests"
                u.font = UIFont.boldSystemFont(ofSize: Const.footnoteFontSize)
                u.textColor = .primary
                u.textAlignment = .right
                u.translatesAutoresizingMaskIntoConstraints = false
                return u
            }()
            
            v.addSubview(u)
            v.addConstraint(NSLayoutConstraint(item: u, attribute: .trailing, relatedBy: .equal, toItem: v, attribute: .trailing, multiplier: 1.0, constant: -24.0))
            v.addConstraint(NSLayoutConstraint(item: u, attribute: .centerY, relatedBy: .equal, toItem: l, attribute: .centerY, multiplier: 1.0, constant: 1.0))
            v.addConstraint(NSLayoutConstraint(item: u, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 16.0))
            v.addConstraint(NSLayoutConstraint(item: u, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 120.0))
        }
        
        return v
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let section = indexPath.section
        
        if sections[section] == "Let's talk about"  {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "InterestTableCell", for: indexPath) as! InterestsUserTableCell
            
            cell.userInterests = userInterests
            cell.myInterests = myInterests

            return cell
            
        } else if sections[section] == "Let's keep in touch" && (sectionDataToDisplay[section]?.count == iconForContactSection.count) {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! ContactInfoTableViewCell
            
            cell.itemTitle.text = sectionDataToDisplay[section]?[indexPath.row]
            cell.itemIcon.image = UIImage(named: iconForContactSection[indexPath.row] as String)?.withRenderingMode(.alwaysTemplate)
            
            cell.selectedBackgroundView = createViewWithBackgroundColor(UIColor.tertiary.withAlphaComponent(0.3))
            return cell
            
        } else {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "AboutCell", for: indexPath) as! DescriptionTableViewCell
            cell.itemDescription.text = sectionDataToDisplay[section]?[indexPath.row]
            cell.itemDescription.formatTextWithLineSpacing(lineSpacing: 6, lineHeightMultiple: 1.05, hyphenation: 0.5, alignment: .left)
            
            cell.selectedBackgroundView = createViewWithBackgroundColor(.background)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let section = indexPath.section
        let row = indexPath.row
        let URLstring = sectionDataToDisplay[section]![row]
        
        if sections[section] == "Let's keep in touch" {
            
            if iconForContactSection[row] == "email" {
                openURLfromString(string: "mailto:\(URLstring)")
                
            } else {
                
                if URLstring.contains("linkedin.com/in"),
                    let URLrange = URLstring.range(of: "linkedin.com/in/") {
                    
                    let profileID = String(URLstring[URLrange.upperBound...])
                    if let url = URL(string: "linkedin://profile/\(profileID)") {
                        
                        UIApplication.shared.open(url, options: [:]) { (result) in
                            if !result {
                                self.openURLfromStringInWebViewer(string: "https://\(URLstring)")
                            }
                        }
                        return
                    }
                    
                } else {
                    
                    openURLfromStringInWebViewer(string: "https://\(URLstring)")
                }
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // Only allows selection of certain cells
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        
        let section = indexPath.section
        
        if sections[section] == "Let's keep in touch" {
            return indexPath
        }
        
        return nil
    }
}
    
// MARK: ScrollViewDidScroll function

extension UserPageViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let topDistance : CGFloat = statusBarHeight //+ barHeight
        let offsetY : CGFloat = scrollView.contentOffset.y
        
        // Zooms out image when scrolled down
        if  offsetY + topDistance < 0 {
            let zoomRatio = (-(offsetY + topDistance) * 0.0065) + 1.0
            backgroundImage.transform = CGAffineTransform(scaleX: zoomRatio, y: zoomRatio)
            
            topbar.alpha(with: 0)
            
        } else {
            
            let delta = headerView.profileImage.frame.maxY == 0.0 ? 1.0 : (headerView.profileImage.frame.maxY - (offsetY + topDistance)) / headerView.profileImage.frame.maxY
            let alpha = delta <= 1.0 ? 1.0 - delta : 1.0
            
            topbar.alpha(with: alpha)
            
            backgroundImage.transform = CGAffineTransform.identity
        }
        
        backgroundImage.layoutIfNeeded()
    }
    
}
