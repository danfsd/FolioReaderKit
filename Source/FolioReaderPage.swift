//
//  FolioReaderPage.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 10/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import SafariServices
import MenuItemKit
import JSQWebViewController

var selectedHighlightId: String?

@objc protocol FolioReaderPageDelegate: class {
    /**
     Notify that the page will load
     
     - parameter page: The page that will be loaded
    */
    @objc optional func pageWillLoad(_ page: FolioReaderPage)
    
    /**
     Notify that page did loaded
     
     - parameter page: The loaded page
     */
    @objc optional func pageDidLoad(_ page: FolioReaderPage)
}

open class FolioReaderPage: UICollectionViewCell, UIWebViewDelegate, UIGestureRecognizerDelegate {
    
    weak var centerDelegate: FolioReaderCenterDelegate?
    weak var delegate: FolioReaderPageDelegate?
    
    open var pageNumber: Int!
    
    var webView: FolioReaderWebView!
    var baseURL: URL!
    var bottomOffset: CGPoint!
    
    fileprivate var colorView: UIView!
    fileprivate var shouldShowBar = true
    fileprivate var menuIsVisible = false
    fileprivate var currentHtml: NSString!
    
    var insertedHighlights = [Highlight]()
    fileprivate var selectedHighlight: Highlight?
    
    var didInsertedAnnotations = false
    
    // MARK: - Initializers
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - View life cicle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPageMode), name: NSNotification.Name(rawValue: "needRefreshPageMode"), object: nil)
        
        if webView == nil {
            webView = FolioReaderWebView(frame: webViewFrame())
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webView.dataDetectorTypes = .link
            webView.scrollView.showsVerticalScrollIndicator = false
            webView.scrollView.showsHorizontalScrollIndicator = false
            webView.backgroundColor = UIColor.clear
            
            self.contentView.addSubview(webView)
        }
        webView.delegate = self
        
        if colorView == nil {
            colorView = UIView()
            colorView.backgroundColor = readerConfig.nightModeBackground
            webView.scrollView.addSubview(colorView)
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.delegate = self
        webView.addGestureRecognizer(tapGestureRecognizer)
        
        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture(_:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.delegate = self
        webView.addGestureRecognizer(doubleTapGestureRecognizer)
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        
        webView.loadHTMLString("", baseURL: baseURL)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        webView.setupScrollDirection()
        webView.frame = webViewFrame()
    }
    
    func webViewFrame() -> CGRect {
        guard readerConfig.hideBars == false else {
            return bounds
        }
        
        let statusbarHeight = UIApplication.shared.statusBarFrame.size.height
        let navBarHeight = FolioReader.sharedInstance.readerCenter.navigationController?.navigationBar.frame.size.height ?? CGFloat(0)
        let navTotal = readerConfig.shouldHideNavigationOnTap ? 0 : statusbarHeight + navBarHeight
        let paddingTop: CGFloat = 20
        let paddingBottom: CGFloat = 30
        
        return CGRect(
            x: bounds.origin.x,
            y: isDirection(bounds.origin.y + navTotal, bounds.origin.y + navTotal + paddingTop),
            width: bounds.width,
            height: isDirection(bounds.height - navTotal, bounds.height - navTotal - paddingTop - paddingBottom)
        )
    }
    
    // MARK: - Interaction
    
    func disableInteraction() {
        if readerConfig.scrollDirection == .horizontal {
        webView.scrollView.isUserInteractionEnabled = false
        webView.isUserInteractionEnabled = false
        FolioReader.sharedInstance.readerCenter.collectionView.isUserInteractionEnabled = false
        }
    }
    
    func enableInteraction() {
        if readerConfig.scrollDirection == .horizontal {
            webView.scrollView.isUserInteractionEnabled = true
            webView.isUserInteractionEnabled = true
            FolioReader.sharedInstance.readerCenter.collectionView.isUserInteractionEnabled = true
        }
    }
    
    // MARK: - HTML String
    
    open func insertHighlights(_ highlights: [Highlight]) {
        guard let center = FolioReader.sharedInstance.readerCenter else { return }
        
        var newHtml = NSString(string: currentHtml).copy() as! NSString
        var didChanged = false
        
        for highlight in highlights {
            let inserted = insertedHighlights.contains(where: { $0.highlightId == highlight.highlightId })
            
            // If the highlight belongs to this page and IS NOT inserted, insert it.
            if highlight.page == pageNumber && !inserted {
                var highlightTag: (tag: String, locator: String)
                
                // Checking whether IT IS an Annotation or a Highlight
                if highlight.type == HighlightStyle.annotation.rawValue {
                    highlightTag = createAnnotationTag(highlight)
                } else {
                    highlightTag = createHighlightTag(highlight)
                }
                
                // If the highlight IS NOT persisted locally on the framework, persist it.
                if Highlight.findByHighlightId(highlight.highlightId) == nil {
                    highlight.persist()
                }
                
                // Generating HTML with the current highlight tag inserted into it.
                newHtml = insertTag(into: newHtml, from: highlight, tag: highlightTag.tag, locator: highlightTag.locator)
                
                // Html did changed.
                didChanged = true
            } else {
                print("Highlight with id \(highlight.highlightId) not persisted, but it's on another page")
            }
        }
        
        if didChanged {
            center.pendingHighlights.removeAll()
            currentHtml = newHtml
            
            webView.alpha = 0
            webView.loadHTMLString(newHtml as String, baseURL: baseURL)
        }
    }
    
    fileprivate func createAnnotationTag(_ highlight: Highlight) -> (tag: String, locator: String) {
        let tag = "<marker data-show=\"true\" id=\"\(highlight.highlightId!)-a\"></marker>\(highlight.content!)"
        
        var locator = "\(highlight.contentPre!)\(highlight.content!)\(highlight.contentPost!)"
        locator = Highlight.removeSentenceSpam(locator) /// Fix for Highlights
        
        return (tag: tag, locator: locator)
    }

    fileprivate func createHighlightTag(_ highlight: Highlight) -> (tag: String, locator: String) {
        let style = HighlightStyle.classForStyle(highlight.type)
        let tag: String
        let isDiscussion = FolioReader.sharedInstance.readerContainer.isDiscussion(highlightWith: highlight.highlightId)
        
        if highlight.type == HighlightStyle.underline.rawValue || highlight.deleted {
            tag = "<marker data-type=\"discussion\" data-show=\"\(isDiscussion)\" id=\"\(highlight.highlightId!)-m\"></marker>\(highlight.content!)"
        } else {
            tag = "<marker data-type=\"discussion\" data-show=\"\(isDiscussion)\" id=\"\(highlight.highlightId!)-m\"></marker><highlight id=\"\(highlight.highlightId!)\" onclick=\"callHighlightURL(this);\" class=\"\(style)\">\(highlight.content!)</highlight>"
        }
        
        var locator = "\(highlight.contentPre!)\(highlight.content!)\(highlight.contentPost!)"
        locator = Highlight.removeSentenceSpam(locator) /// Fix for Highlights
        
        return (tag: tag, locator: locator)
    }
    
    fileprivate func insertTag(into html: NSString, from highlight: Highlight, tag: String, locator: String) -> NSString {
        var newHtml = html
        let range: NSRange = newHtml.range(of: locator, options: .literal)
        
        if range.location != NSNotFound {
            let newRange = NSRange(location: range.location + highlight.contentPre.characters.count, length: highlight.content.characters.count)
            newHtml = html.replacingCharacters(in: newRange, with: tag) as NSString
        }
        
        return newHtml
    }
    
    func loadHTMLString(_ string: String!, baseURL: URL!) {
        let center = FolioReader.sharedInstance.readerCenter!
        
        currentHtml = (string as NSString)
        self.baseURL = baseURL
        
        let bookHighlights = Highlight.allByBookId((kBookId as NSString).deletingPathExtension, andPage: pageNumber as NSNumber?)
        center.pendingHighlights.append(contentsOf: bookHighlights)
        
        webView.alpha = 0
        disableInteraction()
        webView.loadHTMLString(currentHtml as String, baseURL: baseURL)
    }
    
    open func search(withTerm term: String) {
        webView.highlightAllOccurrences(ofString: term)
    }
    
    // MARK: - UIWebViewDelegate
    
    open func webViewDidFinishLoad(_ webView: UIWebView) {
        guard let webView = webView as? FolioReaderWebView, let center = FolioReader.sharedInstance.readerCenter else {
            return
        }
        
        delegate?.pageWillLoad?(self)
        
        refreshPageMode()
        enableInteraction()
        
        if readerConfig.enableTTS && !book.hasAudio() {
            webView.js("wrappingSentencesWithinPTags()");
            
            if FolioReader.sharedInstance.readerAudioPlayer.isPlaying() {
                FolioReader.sharedInstance.readerAudioPlayer.readCurrentSentence()
            }
        }
        
        if readerConfig.scrollDirection != .horizontalWithVerticalContent {
            if scrollDirection == .negative() && isScrolling {
                scrollPageToBottom()
            } else {
                scrollPageToOffset(0.0, animated: false)
            }
        }
        
        isScrolling = false
        
        UIView.animate(withDuration: 0.2, animations: {webView.alpha = 1}, completion: { finished in
            webView.isColors = false
            self.webView.createMenu(options: false)
        })
        
        insertHighlights(center.pendingHighlights)
        
        delegate?.pageDidLoad?(self)
    }
    
    // MARK: - UIWebView interactions
    
    fileprivate func handleDiscussionInteraction(url: URL) {
        let decoded = url.absoluteString.removingPercentEncoding!
        
        let location = "discussion://".characters.count
        let length = decoded.characters.count - location
        let id = (decoded as NSString).substring(with: NSRange(location: location, length: length))
        
        print("Open discussion with id: \(id)")
        
        centerDelegate?.center?(willOpenDiscussionWith: id)
    }
    
    fileprivate func handleAnnotationInteraction(url: URL) {
        let decoded = url.absoluteString.removingPercentEncoding!
        
        let location = "annotation://".characters.count
        let length = decoded.characters.count - location
        let id = (decoded as NSString).substring(with: NSRange(location: location, length: length))
        
        print("Open annotation with id: \(id)")
        
        centerDelegate?.center?(willOpenAnnotationWith: Int(id)!)
    }
    
    fileprivate func handleHighlightInteraction(url: URL) {
        shouldShowBar = false
        let decoded = url.absoluteString.removingPercentEncoding!
        let schemeIndex = decoded.index(decoded.startIndex, offsetBy: 13)
        let decodedSchemeless = decoded.substring(from: schemeIndex)
        
        selectedHighlightId = decodedSchemeless.substring(to: decoded.index(decodedSchemeless.startIndex, offsetBy: 36))
        
        let rect = CGRectFromString(decoded.substring(from: decoded.index(decoded.startIndex, offsetBy: 51)))
        
        webView.createMenu(options: true)
        webView.setMenuVisible(true, andRect: rect)
        menuIsVisible = true
    }
    
    fileprivate func handlePlayAudio(url: URL) {
        guard let audioPlayer = FolioReader.sharedInstance.readerAudioPlayer else { return }
        
        let decoded = url.absoluteString.removingPercentEncoding!
        let playID = decoded.substring(from: decoded.index(decoded.startIndex, offsetBy: 13))
        let chapter = FolioReader.sharedInstance.readerCenter.getCurrentChapter()
        let href = chapter != nil ? chapter!.href : "";
        audioPlayer.playAudio(href!, fragmentID: playID)
    }
    
    fileprivate func handleFileInteraction(url: URL) -> Bool {
        let anchorFromURL = url.fragment
        
        // Handle internal url
        if (url.path as NSString).pathExtension != "" {
            let base = (book.opfResource.href as NSString).deletingLastPathComponent
            let path = url.path
            let splitedPath = path.components(separatedBy: base.isEmpty ? kBookId : base)
            
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
    }
    
    fileprivate func handleAboutBlank(url: URL) {
        if #available(iOS 9.0, *) {
            let safariVC = SFSafariViewController(url: url)
            safariVC.view.tintColor = readerConfig.tintColor
            FolioReader.sharedInstance.readerCenter.present(safariVC, animated: true, completion: nil)
        } else {
            let webViewController = WebViewController(url: url)
            let nav = UINavigationController(rootViewController: webViewController)
            nav.view.tintColor = readerConfig.tintColor
            FolioReader.sharedInstance.readerCenter.present(nav, animated: true, completion: nil)
        }
    }
    
    fileprivate func handleFontChanged() {
        Timer.scheduledTimer(timeInterval: TimeInterval(0.5), target: self, selector: #selector(fontDidChanged), userInfo: nil, repeats: false)
    }
    
    fileprivate func handleSearchJumped(url: URL) {
        let decoded = url.absoluteString.removingPercentEncoding!
        let schemeIndex = decoded.index(decoded.startIndex, offsetBy: "search-jumped://".characters.count)
        let decodedSchemeless = decoded.substring(from: schemeIndex)
        
        let values = decodedSchemeless.components(separatedBy: ",")
        
        centerDelegate?.center?(searchDidJumped: Int(values[0])!, ofTotal: Int(values[1])!)
    }
    
    open func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let webView = webView as? FolioReaderWebView, let url = request.url else {
            return false
        }
        
        if url.scheme == "discussion" {
            handleDiscussionInteraction(url: url)
            return false
        } else if url.scheme == "annotation" {
            handleAnnotationInteraction(url: url)
            return false
        } else if url.scheme == "highlight" {
            handleHighlightInteraction(url: url)
            return false
        } else if url.scheme == "play-audio" {
            handlePlayAudio(url: url)
            return false
        } else if url.scheme == "file" {
            return handleFileInteraction(url: url)
        } else if url.scheme == "mailto" {
            return true
        } else if url.absoluteString != "about:blank" && navigationType == .linkClicked {
            handleAboutBlank(url: url)
            return false
        } else if url.scheme == "font-changed" {
            handleFontChanged()
        } else if url.scheme == "search-jumped" {
            handleSearchJumped(url: url)
        }
        
        return true
    }
    
    func fontDidChanged() {
        let pageSize = isDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = FolioReader.sharedInstance.readerCenter.pageForOffset(webView.scrollView.contentOffset.x, pageHeight: pageSize!)
        let pageState = ReaderState(current: webViewPage, total: totalWebviewPages)
        
        FolioReader.sharedInstance.readerCenter.pageIndicatorView.totalPages = totalWebviewPages
        FolioReader.sharedInstance.readerCenter.pageIndicatorView.currentPage = webViewPage
        
        centerDelegate?.center?(pageDidChanged: self, current: pageState.current, total: pageState.total)
    }
    
    // MARK: Gesture recognizer
    
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
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
    
    /**
     NOT OK
     Handles taps on the `UIWebView`
    */
    func handleTap(_ tapLocation: CGPoint) {
        let lowerTapThreshold = self.webView.frame.size.width * 0.20
        let upperTapThreshold = self.webView.frame.size.width * 0.80
        
        if FolioReader.sharedInstance.readerCenter.navigationController!.isNavigationBarHidden {
            let menuIsVisibleRef = menuIsVisible
            let selected = webView.js("getSelectedText()")
            
            if shouldShowBar && (selected == nil || selected!.characters.count == 0) {
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
                
                if readerConfig.shouldSkipPagesOnEdges {
                    if shouldSkipBackward {
                        FolioReader.sharedInstance.readerCenter.skipPageBackward()
                    } else if shouldSkipForward {
                        FolioReader.sharedInstance.readerCenter.skipPageForward()
                    }
                }
                
                // TODO: remover lógica caso for .horizontalWithVerticalContent
                if !shouldSkipBackward && !shouldSkipForward && !menuIsVisibleRef && !isScrolling {
                    DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
                        FolioReader.sharedInstance.readerContainer.toggleNavigationBar()
                    })
                }
            }
        } else if readerConfig.shouldHideNavigationOnTap == true {
            FolioReader.sharedInstance.readerCenter.hideBars()
        }
        
        // Reset menu
        if menuIsVisible {
            menuIsVisible = false
        } else {
            selectedHighlightId = nil
            shouldShowBar = true
        }
    }
    
    func handleTap(withTimer timer: Timer) {
        let tapLocation = timer.userInfo as! CGPoint
        handleTap(tapLocation)
    }
    
    open func handleDoubleTapGesture(_ recognizer: UITapGestureRecognizer) {
        var seconds = 0.4
        let delay = seconds * Double(NSEC_PER_SEC)  // nanoseconds per seconds
        let dispatchTime = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
        
        DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
            FolioReader.sharedInstance.readerContainer.toggleNavigationBar()
        })
    }
    
    open func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        let tapLocation = recognizer.location(in: recognizer.view)
        
        if isScrolling {
            handleTap(tapLocation)
        } else {
            Timer.scheduledTimer(timeInterval: TimeInterval(0.0), target: self, selector: #selector(self.handleTap(withTimer:)), userInfo: tapLocation, repeats: false)
        }
    }
    
    // MARK: - Scroll and positioning
    
    /**
     Scrolls the page to a given offset
     
     - parameter offset:   The offset to scroll
     - parameter animated: Enable or not scrolling animation
     */
    open func scrollPageToOffset(_ offset: CGFloat, animated: Bool) {
        let pageOffsetPoint = isDirection(CGPoint(x: 0, y: offset), CGPoint(x: offset, y: 0))
        webView.scrollView.setContentOffset(pageOffsetPoint, animated: animated)
    }
    
    /**
     Scrolls the page to a given offset
     
     - parameter offset:   The offset to scroll
     - parameter duration: Animation duration
     */
    open func scrollPageToOffset(_ offset: CGFloat, duration: TimeInterval) {
        let pageOffsetPoint = isDirection(CGPoint(x: 0, y: offset), CGPoint(x: offset, y: 0))
        UIView.animate(withDuration: duration, animations: {
            self.webView.scrollView.contentOffset = pageOffsetPoint
        }) 
    }
    
    /**
     OK
     Scrolls the page to bottom
     */
    open func scrollPageToBottom() {
        let bottomOffset = isDirection(
            CGPoint(x: 0, y: webView.scrollView.contentSize.height - webView.scrollView.bounds.height),
            CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.bounds.width, y: 0),
            CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.bounds.width, y: 0)
        )
        
//        print("Bottom Offset is: \(bottomOffset.forDirection())")
        
        if bottomOffset.forDirection() >= 0 {
            DispatchQueue.main.async(execute: {
                self.webView.scrollView.setContentOffset(bottomOffset, animated: false)
            })
        }
    }
    
    /**
     OK
     Handle #anchors in html, get the offset and scroll to it
     
     - parameter anchor:                The #anchor
     - parameter avoidBeginningAnchors: Sometimes the anchor is on the beggining of the text, there is not need to scroll
     - parameter animated:              Enable or not scrolling animation
     */
    open func handleAnchor(_ anchor: String,  avoidBeginningAnchors: Bool, animated: Bool) {
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
    
    // MARK: Helper
    
    /**
     OK
     Get the #anchor offset in the page
     
     - parameter anchor: The #anchor id
     - returns: The element offset ready to scroll
     */
    func getAnchorOffset(_ anchor: String) -> CGFloat {
        let horizontal = readerConfig.scrollDirection == .horizontal
        if let strOffset = webView.js("getAnchorOffset('\(anchor)', \(horizontal.description))") {
            return CGFloat((strOffset as NSString).floatValue)
        }
        
        return CGFloat(0)
    }
    
    // MARK: Mark ID
    
    /**
     OK
     Audio Mark ID - marks an element with an ID with the given class and scrolls to it
     
     - parameter ID: The ID
     */
    func audioMarkID(_ ID: String) {
        guard let currentPage = FolioReader.sharedInstance.readerCenter?.currentPage else { return }
        currentPage.webView.js("audioMarkID('\(book.playbackActiveClass())','\(ID)')")
    }
    
    // MARK: UIMenu visibility
    
    /**
     NOT OK
     Verifies if the action can be performed
    */
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if UIMenuController.shared.menuItems?.count == 0 {
            webView.isColors = false
            webView.createMenu(options: false)
        }
        
        if !webView.isShare && !webView.isColors {
            if let result = webView.js("getSelectedText()") , result.components(separatedBy: " ").count == 1 {
                webView.isOneWord = true
                webView.createMenu(options: false)
            } else {
                webView.isOneWord = false
            }
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
    
    // MARK: - Public Java Script injection
    
    /**
     Runs a JavaScript script and returns it result. The result of running the JavaScript script passed in the script parameter, or nil if the script fails.
     
     - returns: The result of running the JavaScript script passed in the script parameter, or nil if the script fails.
     */
    open func performJavaScript(_ javaScriptCode: String) -> String? {
        return webView.js(javaScriptCode)
    }
}
