//
//  FolioReaderPage.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 10/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import SafariServices
import UIMenuItem_CXAImageSupport
import JSQWebViewController

protocol FolioReaderPageDelegate: class {
    /**
     Notify that page did loaded
     
     - parameter page: The loaded page
     */
    func pageDidLoad(_ page: FolioReaderPage)
}

class FolioReaderPage: UICollectionViewCell, UIWebViewDelegate, UIGestureRecognizerDelegate {
    
    weak var delegate: FolioReaderPageDelegate?
    var pageNumber: Int!
    var webView: UIWebView!
    var baseURL: URL!
    fileprivate var colorView: UIView!
    fileprivate var shouldShowBar = true
    fileprivate var menuIsVisible = false
    
    // MARK: - View life cicle
    
    override init(frame: CGRect) {
//        print("Page.\(#function)")
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
        
        // TODO: Put the notification name in a Constants file
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPageMode), name: NSNotification.Name(rawValue: "needRefreshPageMode"), object: nil)
        
        if webView == nil {
            webView = UIWebView(frame: webViewFrame())
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webView.dataDetectorTypes = .link
            webView.scrollView.showsVerticalScrollIndicator = false
            webView.scrollView.showsHorizontalScrollIndicator = false
            webView.backgroundColor = UIColor.clear
            
            self.contentView.addSubview(webView)
        }
        webView.delegate = self
        
        if readerConfig.scrollDirection == .horizontal {
            webView.scrollView.isPagingEnabled = true
            webView.paginationMode = .leftToRight
            webView.paginationBreakingMode = .page
            webView.scrollView.bounces = false
        } else {
            webView.scrollView.bounces = true
        }
        
        if colorView == nil {
            colorView = UIView()
            colorView.backgroundColor = readerConfig.nightModeBackground
            webView.scrollView.addSubview(colorView)
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.delegate = self
        webView.addGestureRecognizer(tapGestureRecognizer)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func layoutSubviews() {
//        print("Page.\(#function)")
        super.layoutSubviews()
        
        webView.frame = webViewFrame()
    }
    
    func webViewFrame() -> CGRect {
//        print("Page.\(#function)")
        let paddingTop: CGFloat = 20
        let paddingBottom: CGFloat = 30
        
        guard readerConfig.shouldHideNavigationOnTap else {
            let statusbarHeight = UIApplication.shared.statusBarFrame.size.height
            let navBarHeight = FolioReader.sharedInstance.readerCenter.navigationController?.navigationBar.frame.size.height
            let navTotal = statusbarHeight + navBarHeight!
            let newFrame = CGRect(
                x: bounds.origin.x,
                y: isVerticalDirection(bounds.origin.y + navTotal, bounds.origin.y + navTotal + paddingTop),
                width: bounds.width,
                height: isVerticalDirection(bounds.height - navTotal, bounds.height - navTotal - paddingTop - paddingBottom))
            return newFrame
        }
        
        let newFrame = CGRect(
            x: bounds.origin.x,
            y: isVerticalDirection(bounds.origin.y, bounds.origin.y + paddingTop),
            width: bounds.width,
            height: isVerticalDirection(bounds.height, bounds.height - paddingTop - paddingBottom))
        return newFrame
    }
    
    open func insertHighlights(_ highlights: [Highlight]) {
        if let currentHtml = webView.js("document.documentElement.outerHTML") {
            var newHtml = NSString(string: currentHtml).copy() as! NSString
            var didChanged = false
            
            for highlight in highlights {
                if let _ = Highlight.findByHighlightId(highlight.highlightId) {
                    print("Found highlight with id \(highlight.highlightId), skipping...")
                } else {
                    if highlight.page != pageNumber {
                        print("Didn't found highlight with id \(highlight.highlightId) but it's from another page: \(highlight.page)")
                    } else {
                        print("Didn't found highlight with id \(highlight.highlightId). Adding it to the new HTML...")
                        let highlightTag = createHighlightTag(highlight)
                        let range: NSRange = newHtml.range(of: highlightTag.locator, options: .literal)
                        if range.location != NSNotFound {
                            let newRange = NSRange(location: range.location + highlight.contentPre.characters.count, length: highlight.content.characters.count)
                            newHtml = newHtml.replacingCharacters(in: newRange, with: highlightTag.tag) as NSString
                        }
                        
                        highlight.persist()
                        didChanged = true
                    }
                }
            }
            
            if didChanged {
                webView.loadHTMLString(newHtml as String, baseURL: baseURL)
            }
        }
    }
    
    func createHighlightTag(_ highlight: Highlight) -> (tag: String, locator: String) {
        let style = HighlightStyle.classForStyle(highlight.type)
        let tag = "<highlight id=\"\(highlight.highlightId)\" onclick=\"callHighlightURL(this);\" class=\"\(style)\">\(highlight.content)</highlight>"
        var locator = "\(highlight.contentPre)\(highlight.content)\(highlight.contentPost)"
        locator = Highlight.removeSentenceSpam(locator) /// Fix for Highlights
        
        return (tag: tag, locator: locator)
    }
    
    func loadHTMLString(_ string: String!, baseURL: URL!) {
        var html = (string as NSString)
        self.baseURL = baseURL
        // Restore highlights
        let highlights = Highlight.allByBookId((kBookId as NSString).deletingPathExtension, andPage: pageNumber as NSNumber?)
        
        if highlights.count > 0 {
            for item in highlights {
                let style = HighlightStyle.classForStyle(item.type)
                let tag = "<highlight id=\"\(item.highlightId)\" onclick=\"callHighlightURL(this);\" class=\"\(style)\">\(item.content)</highlight>"
                var locator = "\(item.contentPre)\(item.content)\(item.contentPost)"
                locator = Highlight.removeSentenceSpam(locator) /// Fix for Highlights
                let range: NSRange = html.range(of: locator, options: .literal)
                
                if range.location != NSNotFound {
                    let newRange = NSRange(location: range.location + item.contentPre.characters.count, length: item.content.characters.count)
                    html = html.replacingCharacters(in: newRange, with: tag) as (NSString)
                }
                else {
                    print("highlight range not found")
                }
            }
        }
        
        webView.alpha = 0
        webView.loadHTMLString(html as String, baseURL: baseURL)
    }
    
    // MARK: - UIWebView Delegate
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        refreshPageMode()
        
        if readerConfig.enableTTS && !book.hasAudio() {
            _ = webView.js("wrappingSentencesWithinPTags()");
            
            if FolioReader.sharedInstance.readerAudioPlayer.isPlaying() {
                FolioReader.sharedInstance.readerAudioPlayer.readCurrentSentence()
            }
        }
        
        if scrollDirection == .negative() && isScrolling {
            let bottomOffset = isVerticalDirection(
                CGPoint(x: 0, y: webView.scrollView.contentSize.height - webView.scrollView.bounds.height),
                CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.bounds.width, y: 0)
            )
            
            print("bottomOffset: \(bottomOffset)")
            
            if bottomOffset.forDirection() >= 0 {
                DispatchQueue.main.async(execute: {
                    webView.scrollView.setContentOffset(bottomOffset, animated: false)
                })
            }
        }
        
        isScrolling = false
        
        UIView.animate(withDuration: 0.2, animations: {webView.alpha = 1}, completion: { finished in
            webView.isColors = false
            self.webView.createMenu(false)
        }) 

//        createBoldTag()
        if let highlightsToSync = FolioReader.sharedInstance.readerCenter.highlightsToSync {
            insertHighlights(highlightsToSync)
        }
        
        delegate?.pageDidLoad(self)
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
//        print("Page.\(#function)")
        let url = request.url
        
        if url?.scheme == "highlight" {
            
            shouldShowBar = false
            let decoded = url!.absoluteString.removingPercentEncoding!
            let rect = CGRectFromString(decoded.substring(from: decoded.index(decoded.startIndex, offsetBy: 12)))
            
            webView.createMenu(true)
            webView.setMenuVisible(true, andRect: rect)
            menuIsVisible = true
            
            return false
        } else if url?.scheme == "play-audio" {

            let decoded = url!.absoluteString.removingPercentEncoding!
            let playID = decoded.substring(from: decoded.index(decoded.startIndex, offsetBy: 13))
            let chapter = FolioReader.sharedInstance.readerCenter.getCurrentChapter()
            let href = chapter != nil ? chapter!.href : "";
            FolioReader.sharedInstance.readerAudioPlayer.playAudio(href!, fragmentID: playID)

            return false
        } else if url?.scheme == "file" {
            
            let anchorFromURL = url?.fragment
            
            // Handle internal url
            if (url!.path as NSString).pathExtension != "" {
                let base = (book.opfResource.href as NSString).deletingLastPathComponent
                let path = url?.path
                let splitedPath = path!.components(separatedBy: base.isEmpty ? kBookId : base)
                
                // Return to avoid crash
                if splitedPath.count <= 1 || splitedPath[1].isEmpty {
                    return true
                }
                
                let href = splitedPath[1].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let hrefPage = FolioReader.sharedInstance.readerCenter.findPageByHref(href)+1
                
                if hrefPage == pageNumber {
                    // Handle internal #anchor
                    if anchorFromURL != nil {
                        handleAnchor(anchorFromURL!, avoidBeginningAnchors: false, animated: true)
                        return false
                    }
                } else {
                    FolioReader.sharedInstance.readerCenter.changePageWith(href: href, animated: true, completion: nil)
                }
                
                return false
            }
            
            // Handle internal #anchor
            if anchorFromURL != nil {
                handleAnchor(anchorFromURL!, avoidBeginningAnchors: false, animated: true)
                return false
            }
            
            return true
        } else if url?.scheme == "mailto" {
            print("Email")
            return true
        } else if request.url!.absoluteString != "about:blank" && navigationType == .linkClicked {
            
            if #available(iOS 9.0, *) {
                let safariVC = SFSafariViewController(url: request.url!)
                safariVC.view.tintColor = readerConfig.tintColor
                FolioReader.sharedInstance.readerCenter.present(safariVC, animated: true, completion: nil)
            } else {
                let webViewController = WebViewController(url: request.url!)
                let nav = UINavigationController(rootViewController: webViewController)
                nav.view.tintColor = readerConfig.tintColor
                FolioReader.sharedInstance.readerCenter.present(nav, animated: true, completion: nil)
            }
            return false
        }
        return true
    }
    
    // MARK: Gesture recognizer
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if gestureRecognizer.view is UIWebView {
            if otherGestureRecognizer is UILongPressGestureRecognizer {
                if UIMenuController.shared.isMenuVisible {
                    webView.setMenuVisible(false)
                }
                return false
            }
            return true
        }
        return false
    }
    
    func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
//        webView.setMenuVisible(false)
        let tapLocation = recognizer.location(in: recognizer.view)
        let lowerTapThreshold = self.webView.frame.size.width * 0.20
        let upperTapThreshold = self.webView.frame.size.width * 0.80
        
        if FolioReader.sharedInstance.readerCenter.navigationController!.isNavigationBarHidden {
            let menuIsVisibleRef = menuIsVisible
            
            let selected = webView.js("getSelectedText()")
            
            if selected == nil || selected!.characters.count == 0 {
                var seconds = 0.4
                
                var shouldSkipBackward = false
                var shouldSkipForward = false
                
                if tapLocation.x <= lowerTapThreshold {
                    shouldSkipBackward = true
                    seconds = 0.1
                } else if tapLocation.x >= upperTapThreshold {
                    shouldSkipForward = true
                    seconds = 0.1
                }
                
                let delay = seconds * Double(NSEC_PER_SEC)  // nanoseconds per seconds
                let dispatchTime = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
                
                DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
                    if readerConfig.shouldSkipPagesOnEdges {
                        if shouldSkipBackward {                            FolioReader.sharedInstance.readerCenter.skipPageBackward()
                        } else if shouldSkipForward {
                            FolioReader.sharedInstance.readerCenter.skipPageForward()
                        } else if self.shouldShowBar && !menuIsVisibleRef {
                            FolioReader.sharedInstance.readerContainer.toggleNavigationBar()
                        }
                    } else {
                        if self.shouldShowBar && !menuIsVisibleRef {
                            FolioReader.sharedInstance.readerContainer.toggleNavigationBar()
                        }
                    }
                    self.shouldShowBar = true
                })
            }
        } else if readerConfig.shouldHideNavigationOnTap == true {
            FolioReader.sharedInstance.readerCenter.hideBars()
        }
        
        // Reset menu
        menuIsVisible = false
    }
    
    // MARK: - Scroll and positioning
    
    /**
     Scrolls the page to a given offset
     
     - parameter offset:   The offset to scroll
     - parameter animated: Enable or not scrolling animation
     */
    func scrollPageToOffset(_ offset: CGFloat, animated: Bool) {
//        print("Page.\(#function)")
        let pageOffsetPoint = isVerticalDirection(CGPoint(x: 0, y: offset), CGPoint(x: offset, y: 0))
        webView.scrollView.setContentOffset(pageOffsetPoint, animated: animated)
    }
    
    /**
     Scrolls the page to a given offset
     
     - parameter offset:   The offset to scroll
     - parameter duration: Animation duration
     */
    func scrollPageToOffset(_ offset: CGFloat, duration: TimeInterval) {
        let pageOffsetPoint = isVerticalDirection(CGPoint(x: 0, y: offset), CGPoint(x: offset, y: 0))
        UIView.animate(withDuration: duration, animations: {
            self.webView.scrollView.contentOffset = pageOffsetPoint
        }) 
    }
    
    /**
     Handdle #anchors in html, get the offset and scroll to it
     
     - parameter anchor:                The #anchor
     - parameter avoidBeginningAnchors: Sometimes the anchor is on the beggining of the text, there is not need to scroll
     - parameter animated:              Enable or not scrolling animation
     */
    func handleAnchor(_ anchor: String,  avoidBeginningAnchors: Bool, animated: Bool) {
        if !anchor.isEmpty {
            let offset = getAnchorOffset(anchor)
            
            if readerConfig.scrollDirection == .vertical {
                let isBeginning = offset < frame.forDirection()/2
                
                if !avoidBeginningAnchors {
                    scrollPageToOffset(offset, animated: animated)
                } else if avoidBeginningAnchors && !isBeginning {
                    scrollPageToOffset(offset, animated: animated)
                }
            } else {
                scrollPageToOffset(offset, animated: animated)
            }
        }
    }
    
    /**
     Get the #anchor offset in the page
     
     - parameter anchor: The #anchor id
     - returns: The element offset ready to scroll
     */
    func getAnchorOffset(_ anchor: String) -> CGFloat {
//        print("Page.\(#function)")
        let horizontal = readerConfig.scrollDirection == .horizontal
        if let strOffset = webView.js("getAnchorOffset('\(anchor)', \(horizontal.description))") {
            return CGFloat((strOffset as NSString).floatValue)
        }
        
        return CGFloat(0)
    }
    
    // MARK: Mark ID
    
    /**
     Audio Mark ID - marks an element with an ID with the given class and scrolls to it
     
     - parameter ID: The ID
     */
    func audioMarkID(_ ID: String) {
        let currentPage = FolioReader.sharedInstance.readerCenter.currentPage
        _ = currentPage?.webView.js("audioMarkID('\(book.playbackActiveClass())','\(ID)')")
    }
    
    // MARK: UIMenu visibility
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if UIMenuController.shared.menuItems?.count == 0 {
            webView.isColors = false
            webView.createMenu(false)
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    // MARK: ColorView fix for horizontal layout
    func refreshPageMode() {
        if FolioReader.sharedInstance.nightMode {
            // omit create webView and colorView
            let script = "document.documentElement.offsetHeight"
            let contentHeight = webView.stringByEvaluatingJavaScript(from: script)
            let frameHeight = webView.frame.height
            let lastPageHeight = frameHeight * CGFloat(webView.pageCount) - CGFloat(Double(contentHeight!)!)
            colorView.frame = CGRect(x: webView.frame.width * CGFloat(webView.pageCount-1), y: webView.frame.height - lastPageHeight, width: webView.frame.width, height: lastPageHeight)
        } else {
            colorView.frame = CGRect.zero
        }
    }
}

// MARK: - WebView Highlight and share implementation

private var cAssociationKey: UInt8 = 0
fileprivate var sAssociationKey: UInt8 = 0

extension UIWebView {
    
    var isColors: Bool {
        get { return objc_getAssociatedObject(self, &cAssociationKey) as? Bool ?? false }
        set(newValue) {
            objc_setAssociatedObject(self, &cAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    var isShare: Bool {
        get { return objc_getAssociatedObject(self, &sAssociationKey) as? Bool ?? false }
        set(newValue) {
            objc_setAssociatedObject(self, &sAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        // menu on existing highlight
        if isShare {
            if action == #selector(UIWebView.colors(_:)) || (action == #selector(UIWebView.share(_:)) && readerConfig.allowSharing) || action == #selector(UIWebView.remove(_:)) {
                return true
            }
            return false

        // menu for selecting highlight color
        } else if isColors {
            if action == #selector(UIWebView.setYellow(_:)) || action == #selector(UIWebView.setGreen(_:)) || action == #selector(UIWebView.setBlue(_:)) || action == #selector(UIWebView.setPink(_:)) || action == #selector(UIWebView.setUnderline(_:)) {
                return true
            }
            return false

        // default menu
        } else {
            var isOneWord = false
            if let result = js("getSelectedText()") , result.components(separatedBy: " ").count == 1 {
                isOneWord = true
            }
            
            if action == #selector(UIWebView.highlight(_:))
            || (action == #selector(UIWebView.define(_:)) && isOneWord)
            || (action == #selector(UIWebView.play(_:)) && (book.hasAudio() || readerConfig.enableTTS))
            || (action == #selector(UIWebView.share(_:)) && readerConfig.allowSharing)
            || (action == #selector(NSObject.copy) && readerConfig.allowSharing) {
                return true
            }
            return false
        }
    }
    
    open override var canBecomeFirstResponder : Bool {
        return true
    }
    
    func share(_ sender: UIMenuController) {
        
        if isShare {
            if let textToShare = js("getHighlightContent()") {
                FolioReader.sharedInstance.readerCenter.shareHighlight(textToShare, rect: sender.menuFrame)
            }
        } else {
            if let textToShare = js("getSelectedText()") {
                FolioReader.sharedInstance.readerCenter.shareHighlight(textToShare, rect: sender.menuFrame)
            }
        }
        
        setMenuVisible(false)
    }
    
    func colors(_ sender: UIMenuController?) {
        isColors = true
        createMenu(false)
        setMenuVisible(true)
    }
    
    func remove(_ sender: UIMenuController?) {
        if let removedId = js("removeThisHighlight()") {
            Highlight.removeById(removedId)
            
            FolioReader.sharedInstance.readerContainer.highlightWasRemoved(removedId)
        }
        
        setMenuVisible(false)
    }
    
    func highlight(_ sender: UIMenuController?) {
        let highlightAndReturn = js("highlightString('\(HighlightStyle.classForStyle(FolioReader.sharedInstance.currentHighlightStyle))')")
        let jsonData = highlightAndReturn?.data(using: String.Encoding.utf8)
        
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData!, options: []) as! NSArray
            let dic = json.firstObject as! [String: String]
            let rect = CGRectFromString(dic["rect"]!)
            let startOffset = dic["startOffset"]!
            let endOffset = dic["endOffset"]!
            
            // Force remove text selection
            isUserInteractionEnabled = false
            isUserInteractionEnabled = true

            createMenu(true)
            setMenuVisible(true, andRect: rect)
            
            // Persist
            let html = js("getHTML()")
            if let highlight = Highlight.matchHighlight(html, andId: dic["id"]!, startOffset: startOffset, endOffset: endOffset) {
                highlight.persist()
                
                FolioReader.sharedInstance.readerContainer.highlightWasPersisted(highlight)
            }
        } catch {
            print("Could not receive JSON")
        }
    }

    func define(_ sender: UIMenuController?) {
        let selectedText = js("getSelectedText()")
        
        setMenuVisible(false)
        isUserInteractionEnabled = false
        isUserInteractionEnabled = true
        
        let vc = UIReferenceLibraryViewController(term: selectedText! )
        vc.view.tintColor = readerConfig.tintColor
        FolioReader.sharedInstance.readerContainer.show(vc, sender: nil)
    }

    func play(_ sender: UIMenuController?) {
        FolioReader.sharedInstance.readerAudioPlayer.play()

        // Force remove text selection
        // @NOTE: this doesn't seem to always work
        isUserInteractionEnabled = false
        isUserInteractionEnabled = true
    }


    // MARK: - Set highlight styles
    
    func setYellow(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .yellow)
    }
    
    func setGreen(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .green)
    }
    
    func setBlue(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .blue)
    }
    
    func setPink(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .pink)
    }
    
    func setUnderline(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .underline)
    }

    func changeHighlightStyle(_ sender: UIMenuController?, style: HighlightStyle) {
        FolioReader.sharedInstance.currentHighlightStyle = style.rawValue

        if let updateId = js("setHighlightStyle('\(HighlightStyle.classForStyle(style.rawValue))')") {
            Highlight.updateById(updateId, type: style)
            
            FolioReader.sharedInstance.readerContainer.highlightWasUpdated(updateId, style: style.hashValue)
        }
        colors(sender)
    }
    
    // MARK: - Create and show menu
    
    func createMenu(_ options: Bool) {
        isShare = options
        
        let colors = UIImage(readerImageNamed: "colors-marker")
        let share = UIImage(readerImageNamed: "share-marker")
        let remove = UIImage(readerImageNamed: "no-marker")
        let yellow = UIImage(readerImageNamed: "yellow-marker")
        let green = UIImage(readerImageNamed: "green-marker")
        let blue = UIImage(readerImageNamed: "blue-marker")
        let pink = UIImage(readerImageNamed: "pink-marker")
        let underline = UIImage(readerImageNamed: "underline-marker")
        
        let highlightItem = UIMenuItem(title: readerConfig.localizedHighlightMenu, action: #selector(UIWebView.highlight(_:)))
        let playAudioItem = UIMenuItem(title: readerConfig.localizedPlayMenu, action: #selector(UIWebView.play(_:)))
        let defineItem = UIMenuItem(title: readerConfig.localizedDefineMenu, action: #selector(UIWebView.define(_:)))
        let colorsItem = UIMenuItem(title: "C", image: colors!, action: #selector(UIWebView.colors(_:)))
        let shareItem = UIMenuItem(title: "S", image: share!, action: #selector(UIWebView.share(_:)))
        let removeItem = UIMenuItem(title: "R", image: remove!, action: #selector(UIWebView.remove(_:)))
        let yellowItem = UIMenuItem(title: "Y", image: yellow!, action: #selector(UIWebView.setYellow(_:)))
        let greenItem = UIMenuItem(title: "G", image: green!, action: #selector(UIWebView.setGreen(_:)))
        let blueItem = UIMenuItem(title: "B", image: blue!, action: #selector(UIWebView.setBlue(_:)))
        let pinkItem = UIMenuItem(title: "P", image: pink!, action: #selector(UIWebView.setPink(_:)))
        let underlineItem = UIMenuItem(title: "U", image: underline!, action: #selector(UIWebView.setUnderline(_:)))
        
        let menuItems = [playAudioItem, highlightItem, defineItem, colorsItem, removeItem, yellowItem, greenItem, blueItem, pinkItem, underlineItem, shareItem]

        UIMenuController.shared.menuItems = menuItems
    }
    
    func setMenuVisible(_ menuVisible: Bool, animated: Bool = true, andRect rect: CGRect = CGRect.zero) {
        if !menuVisible && isShare || !menuVisible && isColors {
            isColors = false
            isShare = false
        }
        
        if menuVisible  {
            if !rect.equalTo(CGRect.zero) {
                UIMenuController.shared.setTargetRect(rect, in: self)
            }
        }
        
        UIMenuController.shared.setMenuVisible(menuVisible, animated: animated)
    }
    
    func js(_ script: String) -> String? {
        let callback = self.stringByEvaluatingJavaScript(from: script)
        if callback!.isEmpty { return nil }
        return callback
    }
}

extension UIMenuItem {
    convenience init(title: String, image: UIImage, action: Selector) {
      #if COCOAPODS
        self.init(title: title, action: action)
        self.cxa_init(withTitle: title, action: action, image: image, hidesShadow: true)
      #else
        let settings = CXAMenuItemSettings()
        settings.image = image
        settings.shadowDisabled = true
        self.init(title: title, action: action, settings: settings)
      #endif
    }
}
