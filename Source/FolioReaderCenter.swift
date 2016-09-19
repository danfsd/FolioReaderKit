//
//  FolioReaderCenter.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import ZFDragableModalTransition

let reuseIdentifier = "Cell"
var pageWidth: CGFloat!
var pageHeight: CGFloat!
var previousPageNumber: Int!
var currentPageNumber: Int!
var nextPageNumber: Int!
var scrollDirection = ScrollDirection()
var isScrolling = false

public typealias ReaderState = (current: Int, total: Int)

public enum FolioReaderSkipPageMode: Int {
    case hybrid = 0
    case page = 1
    case chapter = 2
}

public enum FolioReaderFontName: Int {
    case andada = 0
    case lato = 1
    case lora = 2
    case raleway = 3
    
    public func fontName() -> String {
        switch self {
        case .andada: return "andada"
        case .lato: return "lato"
        case .lora: return "lora"
        case .raleway: return "raleway"
        }
    }
    
    public func buttonSelected() -> (serif: Bool, sansSerif: Bool) {
        switch self {
            case .andada: return (serif: true, sansSerif: false)
            case .lato: return (serif: false, sansSerif: true)
            case .lora: return (serif: true, sansSerif: false)
            case .raleway: return (serif: false, sansSerif: true)
        }
    }
}

public enum FolioReaderFontSize: Int {
    case sizeOne = 0
    case sizeTwo = 1
    case sizeThree = 2
    case sizeFour = 3
    case sizeFive = 4
    
    public func fontSize() -> String {
        switch self {
        case .sizeOne: return "textSizeOne"
        case .sizeTwo: return "textSizeTwo"
        case .sizeThree: return "textSizeThree"
        case .sizeFour: return "textSizeFour"
        case .sizeFive: return "textSizeFive"
        }
    }
    
    public func sliderValue() -> Float {
        switch self {
        case .sizeOne: return 0.0
        case .sizeTwo: return 0.21
        case .sizeThree: return 0.41
        case .sizeFour: return 0.61
        case .sizeFive: return 0.81
        }
    }
}

public enum FolioReaderTextAlignemnt: Int {
    case left = 0
    case right = 1
    case center = 2
    case justify = 3
    
    public func textAlignment() -> String {
        switch self {
        case .left: return"left"
        case .right: return "right"
        case .center: return "center"
        case .justify: return "justify"
        }
    }
    
    public func buttonSelected() -> (left: Bool, justify: Bool) {
        switch self {
        case .left: return (left: true, justify: false)
        case .justify: return (left: false, justify: true)
            
        // Not used
        case .right: return (left: true, justify: false)
        case .center: return (left: true, justify: false)
        }
    }
}

open class FolioReaderCenter: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    var collectionView: UICollectionView!
    var loadingView: UIActivityIndicatorView!
    var pages: [String]!
    var totalPages: Int!
    var tempFragment: String?
    
    var currentPage: FolioReaderPage!
    var highlightsToSync: [Highlight]?
    open var delegate: FolioReaderCenterDelegate?
    var animator: ZFModalTransitionAnimator!
    var pageIndicatorView: FolioReaderPageIndicator!
    var bookShareLink: String?
    
    var recentlyScrolled = false
    var recentlyScrolledDelay = 2.0 // 2 second delay until we clear recentlyScrolled
    var recentlyScrolledTimer: Timer!
    var scrollScrubber: ScrollScrubber!
    
    fileprivate var screenBounds: CGRect!
    fileprivate var pointNow = CGPoint.zero
    fileprivate let pageIndicatorHeight: CGFloat = 20
    fileprivate var pageOffsetRate: CGFloat = 0
    fileprivate var internalOffsetPortrait: CGPoint?
    fileprivate var internalOffsetLandscape: CGPoint?
    fileprivate var tempReference: FRTocReference?
    fileprivate var isFirstLoad = true
    
    // MARK: - View life cicle
    
    override open func viewDidLoad() {
//        print("Center.\(#function)")
        super.viewDidLoad()
        
        screenBounds = UIScreen.main.bounds
        setPageSize(UIApplication.shared.statusBarOrientation)
        
        // Layout
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets.zero
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .direction()
        
        let background = isNight(readerConfig.nightModeBackground, UIColor.white)
        view.backgroundColor = background
        
        // CollectionView
        collectionView = UICollectionView(frame: screenBounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = background
        collectionView.decelerationRate = UIScrollViewDecelerationRateFast
        view.addSubview(collectionView)
        
        // Register cell classes
        collectionView!.register(FolioReaderPage.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        totalPages = book.spine.spineReferences.count
        
        // Configure navigation bar and layout
        automaticallyAdjustsScrollViewInsets = false
        extendedLayoutIncludesOpaqueBars = true
        configureNavBar()
        
        // Page indicator view
        pageIndicatorView = FolioReaderPageIndicator(frame: CGRect(x: 0, y: view.frame.height-pageIndicatorHeight, width: view.frame.width, height: pageIndicatorHeight))
        view.addSubview(pageIndicatorView)
        
        let scrubberY: CGFloat = readerConfig.shouldHideNavigationOnTap == true ? 50 : 74
        scrollScrubber = ScrollScrubber(frame: CGRect(x: pageWidth + 10, y: scrubberY, width: 40, height: pageHeight - 100))
        scrollScrubber.delegate = self
        view.addSubview(scrollScrubber.slider)
        
        // Loading indicator
        let style: UIActivityIndicatorViewStyle = isNight(.white, .gray)
        loadingView = UIActivityIndicatorView(activityIndicatorStyle: style)
        loadingView.center = view.center
        loadingView.hidesWhenStopped = true
        loadingView.startAnimating()
        view.addSubview(loadingView)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
//        print("Center.\(#function)")
        super.viewWillAppear(animated)
        
        // Update pages
        pagesForCurrentPage(currentPage)
        pageIndicatorView.reloadView(true)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
//        print("Center.\(#function)")
        super.viewDidAppear(animated)
    }

    func configureNavBar() {
        if !readerConfig.shouldHideNavigation {
            let navBackground = isNight(readerConfig.nightModeMenuBackground, UIColor.white)
            let tintColor = readerConfig.tintColor
            let navText = isNight(UIColor.white, UIColor.black)
            let font = UIFont(name: "Avenir-Light", size: 17)!
            setTranslucentNavigation(color: navBackground, tintColor: tintColor, titleColor: navText, andFont: font)
        }
    }
    
    func configureNavBarButtons() {
        if !readerConfig.shouldHideNavigation {
            // Navbar buttons
            let shareIcon = UIImage(readerImageNamed: "icon-navbar-share")?.ignoreSystemTint()
            let audioIcon = UIImage(readerImageNamed: "icon-navbar-tts")?.ignoreSystemTint() //man-speech-icon
            let closeIcon = UIImage(readerImageNamed: "icon-navbar-close")?.ignoreSystemTint()
            let tocIcon = UIImage(readerImageNamed: "icon-navbar-toc")?.ignoreSystemTint()
            let fontIcon = UIImage(readerImageNamed: "icon-navbar-font")?.ignoreSystemTint()
            let space = 70 as CGFloat

            let menu = UIBarButtonItem(image: closeIcon, style: .plain, target: self, action:#selector(closeReader(_:)))
            let toc = UIBarButtonItem(image: tocIcon, style: .plain, target: self, action:#selector(presentChapterList(_:)))
            
            navigationItem.leftBarButtonItems = [menu, toc]
            
            var rightBarIcons = [UIBarButtonItem]()

            if readerConfig.allowSharing {
                rightBarIcons.append(UIBarButtonItem(image: shareIcon, style: .plain, target: self, action:#selector(shareChapter(_:))))
            }

            if book.hasAudio() || readerConfig.enableTTS {
                rightBarIcons.append(UIBarButtonItem(image: audioIcon, style: .plain, target: self, action:#selector(presentPlayerMenu(_:))))
            }
            
            let font = UIBarButtonItem(image: fontIcon, style: .plain, target: self, action: #selector(presentFontsMenu))
            font.width = space
            
            rightBarIcons.append(contentsOf: [font])
            navigationItem.rightBarButtonItems = rightBarIcons
        }
    }

    func reloadData() {
//        print("Center.\(#function)")
        loadingView.stopAnimating()
        bookShareLink = readerConfig.localizedShareWebLink
        totalPages = book.spine.spineReferences.count

        collectionView.reloadData()
        configureNavBarButtons()
        
        if let position = FolioReader.defaults.value(forKey: kBookId) as? NSDictionary,
            let pageNumber = position["pageNumber"] as? Int , pageNumber > 0 {
            changePageWith(page: pageNumber)
            currentPageNumber = pageNumber
            return
        }
        
        currentPageNumber = 1
    }
    
    override open var shouldAutorotate : Bool {
        return true
    }
    
    override open var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.allButUpsideDown
    }
    
    // MARK: Status bar and Navigation bar
    
    func hideBars() {

        if readerConfig.shouldHideNavigationOnTap == false { return }

        let shouldHide = true
        FolioReader.sharedInstance.readerContainer.shouldHideStatusBar = shouldHide
        
        UIView.animate(withDuration: 0.25, animations: {
            FolioReader.sharedInstance.readerContainer.setNeedsStatusBarAppearanceUpdate()
        })
        navigationController?.setNavigationBarHidden(shouldHide, animated: true)
    }
    
    func showBars() {
        configureNavBar()
        
        let shouldHide = false
        FolioReader.sharedInstance.readerContainer.shouldHideStatusBar = shouldHide
        
        UIView.animate(withDuration: 0.25, animations: {
            FolioReader.sharedInstance.readerContainer.setNeedsStatusBarAppearanceUpdate()
        })
        navigationController?.setNavigationBarHidden(shouldHide, animated: true)
    }
    
    func toggleBars() {
        if readerConfig.shouldHideNavigationOnTap == false { return }
        
        let shouldHide = !navigationController!.isNavigationBarHidden
        if !shouldHide { configureNavBar() }
        
        FolioReader.sharedInstance.readerContainer.shouldHideStatusBar = shouldHide
        
        UIView.animate(withDuration: 0.25, animations: {
            FolioReader.sharedInstance.readerContainer.setNeedsStatusBarAppearanceUpdate()
        })
        navigationController?.setNavigationBarHidden(shouldHide, animated: true)
    }
    
    open func setFontName(_ name: FolioReaderFontName) {
        print("setFontName('\(name.fontName())')")
        FolioReader.sharedInstance.currentFontName = name.rawValue
        _ = currentPage.webView.js("setFontName('\(name.fontName())')")
    }
    
    open func setFontSize(_ style: FolioReaderFontSize) {
        print("setFontSize('\(style.fontSize())')")
        FolioReader.sharedInstance.currentFontSize = style.rawValue
        
        let pageSize = isVerticalDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageSize!)
        let pageState = ReaderState(current: webViewPage, total: totalWebviewPages)
        
        FolioReader.sharedInstance.readerContainer.webviewPageDidChanged(pageState)
        
        _ = currentPage.webView.js("setFontSize('\(style.fontSize())')")
    }
    
    open func setTextAlignment(_ style: FolioReaderTextAlignemnt) {
        print("setTextAlignment('\(style.textAlignment())')")
        FolioReader.sharedInstance.currentTextAlignement = style.rawValue
        _ = currentPage.webView.js("setTextAlignment('\(style.textAlignment())')")
    }
    
    // MARK: UICollectionViewDataSource
    
    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalPages
    }
    
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        print("Center.\(#function)")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! FolioReaderPage
        
        cell.pageNumber = (indexPath as NSIndexPath).row+1
        cell.webView.scrollView.delegate = self
        cell.delegate = self
        cell.backgroundColor = UIColor.clear
        
        // Configure the cell
        let resource = book.spine.spineReferences[indexPath.row].resource
        var html = try? String(contentsOfFile: (resource?.fullHref)!, encoding: String.Encoding.utf8)
        let mediaOverlayStyleColors = "\"\(readerConfig.mediaOverlayColor.hexString(false))\", \"\(readerConfig.mediaOverlayColor.highlightColor().hexString(false))\""

        // Inject CSS
        let jsFilePath = Bundle.frameworkBundle().path(forResource: "Bridge", ofType: "js")
        let cssFilePath = Bundle.frameworkBundle().path(forResource: "Style", ofType: "css")
        let cssTag = "<link rel=\"stylesheet\" type=\"text/css\" href=\"\(cssFilePath!)\">"
        let jsTag = "<script type=\"text/javascript\" src=\"\(jsFilePath!)\"></script>" +
                    "<script type=\"text/javascript\">setMediaOverlayStyleColors(\(mediaOverlayStyleColors))</script>"
        
        let toInject = "\n\(cssTag)\n\(jsTag)\n</head>"
        html = html?.replacingOccurrences(of: "</head>", with: toInject)
        
        // Font class name
        var classes = ""
        let currentFontName = FolioReader.sharedInstance.currentFontName
        switch currentFontName {
        case 0:
            classes = "andada"
            break
        case 1:
            classes = "lato"
            break
        case 2:
            classes = "lora"
            break
        case 3:
            classes = "raleway"
            break
        default:
            break
        }
        
        classes += " " + FolioReader.sharedInstance.currentMediaOverlayStyle.className()
        
        // Night mode
        if FolioReader.sharedInstance.nightMode {
            classes += " nightMode"
        }
        
        // Text Alignment
        let textAlignment = FolioReader.sharedInstance.currentTextAlignement
        let style = "text-align: \(FolioReaderTextAlignemnt(rawValue: textAlignment)!.textAlignment())"
        
        // Font Size
        let currentFontSize = FolioReader.sharedInstance.currentFontSize
        switch currentFontSize {
        case 0:
            classes += " textSizeOne"
            break
        case 1:
            classes += " textSizeTwo"
            break
        case 2:
            classes += " textSizeThree"
            break
        case 3:
            classes += " textSizeFour"
            break
        case 4:
            classes += " textSizeFive"
            break
        default:
            break
        }
        
        html = html?.replacingOccurrences(of: "<html ", with: "<html class=\"\(classes)\" style=\"\(style)\"")
        
        cell.loadHTMLString(html, baseURL: URL(fileURLWithPath: (NSString(string: resource!.fullHref)).deletingLastPathComponent))
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        return CGSize(width: pageWidth, height: pageHeight)
    }
    
    // MARK: - Device rotation
    
    override open func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        if !FolioReader.sharedInstance.isReaderReady { return }
        
        setPageSize(toInterfaceOrientation)
        updateCurrentPage()
        
        var pageIndicatorFrame = pageIndicatorView.frame
        pageIndicatorFrame.origin.y = pageHeight-pageIndicatorHeight
        pageIndicatorFrame.origin.x = 0
        pageIndicatorFrame.size.width = pageWidth
        
        var scrollScrubberFrame = scrollScrubber.slider.frame;
        scrollScrubberFrame.origin.x = pageWidth + 10
        scrollScrubberFrame.size.height = pageHeight - 100
        
        UIView.animate(withDuration: duration, animations: {
            
            // Adjust page indicator view
            self.pageIndicatorView.frame = pageIndicatorFrame
            self.pageIndicatorView.reloadView(true)
            
            // Adjust scroll scrubber slider
            self.scrollScrubber.slider.frame = scrollScrubberFrame
            
            // Adjust collectionView
            self.collectionView.contentSize = isVerticalDirection(
                CGSize(width: pageWidth, height: pageHeight * CGFloat(self.totalPages)),
                CGSize(width: pageWidth * CGFloat(self.totalPages), height: pageHeight)
            )
            self.collectionView.setContentOffset(self.frameForPage(page: currentPageNumber).origin, animated: false)
            self.collectionView.collectionViewLayout.invalidateLayout()
            
            // Adjust internal page offset
            let pageScrollView = self.currentPage.webView.scrollView
            
            // Salvando o offset da orientação atual
            
            self.saveOffset(forOrientation: UIApplication.shared.statusBarOrientation, offset: pageScrollView.contentOffset)
            self.pageOffsetRate = pageScrollView.contentOffset.forDirection() / pageScrollView.contentSize.forDirection()
        })
    }
    
    func saveOffset(forOrientation orientation: UIInterfaceOrientation, offset: CGPoint?) {
        if orientation.isPortrait {
            internalOffsetPortrait = offset
        } else {
            internalOffsetLandscape = offset
        }
    }
    
    func internalOffset(forOrientation orientation: UIInterfaceOrientation) -> CGPoint? {
        return orientation.isPortrait ? internalOffsetPortrait : internalOffsetLandscape
    }
    
    override open func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        if !FolioReader.sharedInstance.isReaderReady { return }
        
        // Update pages
        pagesForCurrentPage(currentPage)
        
        scrollScrubber.setSliderVal()
        
        // After rotation fix internal page offset
        // var pageOffset = self.currentPage.webView.scrollView.contentSize.forDirection() * pageOffsetRate
        var pageOffset: CGFloat!
        if let previousOffset = internalOffset(forOrientation: UIApplication.shared.statusBarOrientation) {
            pageOffset = previousOffset.forDirection()
            print("Using previous \(UIApplication.shared.statusBarOrientation.isPortrait ? "portrait" : "landscape") offset: \(pageOffset)")
        } else {
            pageOffset = self.currentPage.webView.scrollView.contentSize.forDirection() * pageOffsetRate
            print("Using offset rate for \(UIApplication.shared.statusBarOrientation.isPortrait ? "portrait" : "landscape") orientation: \(pageOffset)")
        }
        
        // Fix the offset for paged scroll
        if readerConfig.scrollDirection == .horizontal {
            let page = round(pageOffset / pageWidth)
            pageOffset = page * pageWidth
        }
        
        let pageOffsetPoint = isVerticalDirection(CGPoint(x: 0, y: pageOffset), CGPoint(x: pageOffset, y: 0))
        self.currentPage.webView.scrollView.setContentOffset(pageOffsetPoint, animated: true)
    }
    
    override open func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        if !FolioReader.sharedInstance.isReaderReady { return }
        
        if currentPageNumber+1 >= totalPages {
            UIView.animate(withDuration: duration, animations: {
                self.collectionView.setContentOffset(self.frameForPage(page: currentPageNumber).origin, animated: false)
            })
        }
    }
    
    // MARK: - Page
    
    func setPageSize(_ orientation: UIInterfaceOrientation) {
        if orientation.isPortrait {
            if screenBounds.size.width < screenBounds.size.height {
                pageWidth = screenBounds.size.width
                pageHeight = screenBounds.size.height
            } else {
                pageWidth = screenBounds.size.height
                pageHeight = screenBounds.size.width
            }
        } else {
            if screenBounds.size.width > screenBounds.size.height {
                pageWidth = screenBounds.size.width
                pageHeight = screenBounds.size.height
            } else {
                pageWidth = screenBounds.size.height
                pageHeight = screenBounds.size.width
            }
        }
    }
    
    func updateCurrentPage(_ completion: (() -> Void)? = nil) {
        updateCurrentPage(nil) { () -> Void in
            completion?()
        }
    }
    
    func updateCurrentPage(_ page: FolioReaderPage!, completion: (() -> Void)? = nil) {
//        print("Center.\(#function)")
        if let page = page {
            currentPage = page
            previousPageNumber = page.pageNumber - 1
            currentPageNumber = page.pageNumber
        } else {
            let currentIndexPath = getCurrentIndexPath()
            print("Index path row: \((currentIndexPath as NSIndexPath).row)")
            if currentIndexPath != IndexPath(row: 0, section: 0) {
                currentPage = collectionView.cellForItem(at: currentIndexPath) as! FolioReaderPage
                previousPageNumber = (currentIndexPath as NSIndexPath).row
                currentPageNumber = (currentIndexPath as NSIndexPath).row + 1
            } else if let page = collectionView.cellForItem(at: currentIndexPath) {
                currentPage = page as! FolioReaderPage
                previousPageNumber = currentPage.pageNumber - 1
                currentPageNumber = currentPage.pageNumber
            }
            
//            previousPageNumber = currentIndexPath.row
//            currentPageNumber = currentIndexPath.row+1
        }
        
        nextPageNumber = currentPageNumber + 1 <= totalPages ? currentPageNumber + 1 : currentPageNumber
        
        // Set navigation title
        // TODO: rever essa zueira pra quando não tem título
        if let chapterName = getCurrentChapterName() {
            title = chapterName
            FolioReader.sharedInstance.readerContainer.chapterDidChanged(chapterName)
        } else { title = ""}
        
        // Set pages
        if let page = currentPage {
            page.webView.becomeFirstResponder()
            
            scrollScrubber.setSliderVal()
            
            let jsReadingTime = page.webView.js("getReadingTime()")
            let readingTime = jsReadingTime != nil ? Int(jsReadingTime!) : 0
            
            pageIndicatorView.totalMinutes = readingTime
            
            FolioReader.sharedInstance.readerContainer.readingTimeDidChanged(readingTime!)
            
            pagesForCurrentPage(page)
        }
        
        completion?()
    }
    
    func pagesForCurrentPage(_ page: FolioReaderPage?) {
//        print("Center.\(#function)")
        if let page = page {
            let pageSize = isVerticalDirection(pageHeight, pageWidth)
            let totalWebviewPages = Int(ceil(page.webView.scrollView.contentSize.forDirection()/pageSize!))
            
            pageIndicatorView.totalPages = totalWebviewPages
            let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageSize!)
            pageIndicatorView.currentPage = webViewPage
            
            let chapterState = ReaderState(current: currentPageNumber, total: totalPages)
            let pageState = ReaderState(current: webViewPage, total: totalWebviewPages)
            
            FolioReader.sharedInstance.readerContainer.pageDidChanged(chapterState, pageState: pageState)
        }
    }
    
    func pageForOffset(_ offset: CGFloat, pageHeight height: CGFloat) -> Int {
        let page = Int(ceil(offset / height))+1
        return page
    }
    
    func getCurrentIndexPath() -> IndexPath {
        let indexPaths = collectionView.indexPathsForVisibleItems
        var indexPath = IndexPath()
        
        if indexPaths.count > 1 {
            let first = indexPaths.first! as IndexPath
            let last = indexPaths.last! as IndexPath
            
            switch scrollDirection {
            case .up:
                if (first as NSIndexPath).compare(last) == .orderedAscending {
                    indexPath = last
                } else {
                    indexPath = first
                }
            case .left:
                if (first as NSIndexPath).compare(last) == .orderedDescending {
                    indexPath = first
                } else {
                    indexPath = last
                }
            default:
                if (first as NSIndexPath).compare(last) == .orderedAscending {
                    indexPath = first
                } else {
                    indexPath = last
                }
            }
        } else {
            indexPath = indexPaths.first ?? IndexPath(row: 0, section: 0)
        }
        
        return indexPath
    }
    
    func frameForPage(page: Int) -> CGRect {
        return isVerticalDirection(
            CGRect(x: 0, y: pageHeight * CGFloat(page-1), width: pageWidth, height: pageHeight),
            CGRect(x: pageWidth * CGFloat(page-1), y: 0, width: pageWidth, height: pageHeight)
        )
    }
    
    func changePageWith(page: Int, animated: Bool = false, completion: (() -> Void)? = nil) {
        if page > 0 && page-1 < totalPages {
            let indexPath = IndexPath(row: page-1, section: 0)
            
            changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
                self.updateCurrentPage({ () -> Void in
                    completion?()
                })
            })
        }
    }
    
    open func changePageWith(page: Int, andFragment fragment: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        if currentPageNumber == page {
            if fragment != "" && currentPage != nil {
                currentPage.handleAnchor(fragment, avoidBeginningAnchors: true, animated: animated)
                completion?()
            }
        } else {
            tempFragment = fragment
            changePageWith(page: page, animated: animated, completion: { () -> Void in
                self.updateCurrentPage({ () -> Void in
                    completion?()
                })
            })
        }
    }
    
    func changePageWith(href: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        let item = findPageByHref(href)
        let indexPath = IndexPath(row: item, section: 0)
        changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
            self.updateCurrentPage({ () -> Void in
                completion?()
            })
        })
    }

    func changePageWith(href: String, andAudioMarkID markID: String) {
        if recentlyScrolled { return } // if user recently scrolled, do not change pages or scroll the webview

        let item = findPageByHref(href)
        let pageUpdateNeeded = item+1 != currentPage.pageNumber
        let indexPath = IndexPath(row: item, section: 0)
        changePageWith(indexPath: indexPath, animated: true) { () -> Void in
            if pageUpdateNeeded {
                self.updateCurrentPage({ () -> Void in
                    self.currentPage.audioMarkID(markID)
                })
            } else {
                self.currentPage.audioMarkID(markID)
            }
        }
    }
    
    open func skipToFirstPage() {
//        changePageWith(page: 1)
        changeToPage(1, scrolling: false)
    }
    
    open func skipPageForward(_ skipMode: FolioReaderSkipPageMode = .hybrid) {
        let pageSize = isVerticalDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageSize!)
        
        switch skipMode {
        case .hybrid:
            if webViewPage < totalWebviewPages {
                print("scrolling webview \(webViewPage)/\(totalWebviewPages)")
                let currentOffset = currentPage.webView.scrollView.contentOffset
                let pageState = ReaderState(current: webViewPage + 1, total: totalWebviewPages)
                FolioReader.sharedInstance.readerContainer.webviewPageDidChanged(pageState)
                currentPage.scrollPageToOffset(currentOffset.x + pageSize!, animated: true)
            } else if nextPageNumber <= totalPages {
                print("scrolling collectionView \(currentPageNumber)\(totalPages) next: \(nextPageNumber)")
                changeToPage(nextPageNumber, scrolling: false)
            }
            break
        case .chapter:
            guard nextPageNumber <= totalPages else { return }
            
            print("scrolling collectionView \(currentPageNumber)\(totalPages) next: \(nextPageNumber)")
            changeToPage(nextPageNumber, scrolling: false)
            // TODO: pageDidChanged
            
            break
        case .page:
            guard webViewPage < totalWebviewPages else { return }
            
            print("scrolling webview \(webViewPage)/\(totalPages)")
            let currentOffset = currentPage.webView.scrollView.contentOffset
            let pageState = ReaderState(current: webViewPage + 1, total: totalWebviewPages)
            FolioReader.sharedInstance.readerContainer.webviewPageDidChanged(pageState)
            currentPage.scrollPageToOffset(currentOffset.x + pageSize!, duration: 0.1)
            
            break
        }
    }
    
    open func skipPageBackward(_ skipMode: FolioReaderSkipPageMode = .hybrid) {
        let pageSize = isVerticalDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageSize!)
        
        switch skipMode {
        case .hybrid:
            if webViewPage > 1 {
                let currentOffset = currentPage.webView.scrollView.contentOffset
                print("scrolling webview \(webViewPage)/\(totalPages)")
                let pageState = ReaderState(current: webViewPage - 1, total: totalWebviewPages)
                FolioReader.sharedInstance.readerContainer.webviewPageDidChanged(pageState)
                currentPage.scrollPageToOffset(currentOffset.x - pageSize!, animated: true)
            } else if previousPageNumber >= 1 {
                print("scrolling collectionView \(currentPageNumber)\(totalPages) previous: \(previousPageNumber)")
                changeToPage(previousPageNumber, scrolling: true)
            }
            break
        case .chapter:
            guard previousPageNumber >= 1 else { return }
            
            print("scrolling collectionView \(currentPageNumber)\(totalPages) previous: \(previousPageNumber)")
            changeToPage(previousPageNumber, scrolling: false)
            // TODO: pageDidChanged
            
            break
        case .page:
            guard webViewPage > 1 else { return }
            
            let currentOffset = currentPage.webView.scrollView.contentOffset
            print("scrolling webview \(webViewPage)/\(totalPages)")
            let pageState = ReaderState(current: webViewPage - 1, total: totalWebviewPages)
            FolioReader.sharedInstance.readerContainer.webviewPageDidChanged(pageState)
            currentPage.scrollPageToOffset(currentOffset.x - pageSize!, animated: true)
            
            break
        }
    }

    func changePageWith(indexPath: IndexPath, animated: Bool = false, completion: (() -> Void)? = nil) {
        guard indexPathIsValid(indexPath) else {
            print("ERROR: Attempt to scroll to invalid index path")
            completion?()
            return
        }
        
        self.pointNow = self.collectionView.contentOffset
        // isScrolling = true
        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: UIViewAnimationOptions(), animations: { () -> Void in
            self.collectionView.scrollToItem(at: indexPath, at: .direction(), animated: false)
        }) { (finished: Bool) -> Void in
            completion?()
        }
    }
    
    func changeToPage(_ page: Int, scrolling: Bool = true, animated: Bool = false, completion: (() -> Void)? = nil) {
        if page > 0 && page-1 < totalPages {
            let indexPath = IndexPath(row: page-1, section: 0)
            changeToPage(atIndexPath: indexPath, scrolling: scrolling, animated: animated, completion: { () -> Void in
                self.updateCurrentPage({ () -> Void in
                    completion?()
                })
            })
        }
    }
    
    func changeToPage(atIndexPath indexPath: IndexPath, scrolling: Bool = true, animated: Bool = false, completion: (() -> Void)? = nil) {
        guard indexPathIsValid(indexPath) else {
            print("ERROR: Attempt to scroll at invalid index path")
            completion?()
            return
        }
        
        pointNow = collectionView.contentOffset
        isScrolling = scrolling
        
        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.collectionView.scrollToItem(at: indexPath, at: .direction(), animated: false)
        }) { (finished: Bool) -> Void in
            completion?()
        }
        
    }
    
    func indexPathIsValid(_ indexPath: IndexPath) -> Bool {
        let section = (indexPath as NSIndexPath).section
        let row = (indexPath as NSIndexPath).row
        let lastSectionIndex = numberOfSections(in: collectionView) - 1
        
        //Make sure the specified section exists
        if section > lastSectionIndex {
            return false
        }
        
        let rowCount = self.collectionView(collectionView, numberOfItemsInSection: (indexPath as NSIndexPath).section) - 1
        return row <= rowCount
    }
    
    func isLastPage() -> Bool{
        return currentPageNumber == nextPageNumber
    }

    func changePageToNext(_ completion: (() -> Void)? = nil) {
        changePageWith(page: nextPageNumber, animated: true) { () -> Void in
            completion?()
        }
    }
    
    func changePageToPrevious(_ completion: (() -> Void)? = nil) {
        changePageWith(page: previousPageNumber, animated: true) { () -> Void in
            completion?()
        }
    }

    /**
     Find a page by FRTocReference.
    */
    func findPageByResource(_ reference: FRTocReference) -> Int {
        var count = 0
        for item in book.spine.spineReferences {
            if let resource = reference.resource , item.resource == resource {
                return count
            }
            count += 1
        }
        return count
    }
    
    /**
     Find a page by href.
    */
    func findPageByHref(_ href: String) -> Int {
        var count = 0
        for item in book.spine.spineReferences {
            if item.resource.href == href {
                return count
            }
            count += 1
        }
        return count
    }
    
    /**
     Find and return the current chapter resource.
    */
    func getCurrentChapter() -> FRResource? {
        if let currentPageNumber = currentPageNumber {
            for item in book.flatTableOfContents {
                if let reference = book.spine.spineReferences[safe: currentPageNumber-1], let resource = item.resource
                    , resource == reference.resource {
                    return item.resource
                }
            }
        }
        return nil
    }

    /**
     Find and return the current chapter name.
     */
    func getCurrentChapterName() -> String? {
        if let currentPageNumber = currentPageNumber {
            let toc = book.getTableOfContents()
            for item in toc! {
                if let reference = book.spine.spineReferences[safe: currentPageNumber - 1], let resource = item.resource , resource.href == reference.resource.href {
                    if let title = item.title {
                        return title
                    }
                    return nil
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Audio Playing

    func audioMark(href: String, fragmentID: String) {
        changePageWith(href: href, andAudioMarkID: fragmentID)
    }
    
    // MARK: - Highlight
    
    open func synchronizeHighlights(_ highlights: [Highlight]) {
        if let _ = currentPage {
            currentPage.insertHighlights(highlights)
        } else {
            highlightsToSync = highlights
        }
    }
    
    open func removeHighlight(withId highlightId: String) {
        Highlight.removeById(highlightId)
        _ = Highlight.removeFromHTMLById(highlightId)
        
        FolioReader.sharedInstance.readerContainer.highlightWasRemoved(highlightId)
    }
    
    // MARK: - Sharing
    
    /**
     Sharing chapter method.
    */
    func shareChapter(_ sender: UIBarButtonItem) {
        
        if let chapterText = currentPage.webView.js("getBodyText()") {
            
            let htmlText = chapterText.replacingOccurrences(of: "[\\n\\r]+", with: "<br />", options: .regularExpression)

            var subject = readerConfig.localizedShareChapterSubject
            var html = ""
            var text = ""
            var bookTitle = ""
            var chapterName = ""
            var authorName = ""
            
            // Get book title
            if let title = book.title() {
                bookTitle = title
                subject += " “\(title)”"
            }
            
            // Get chapter name
            if let chapter = getCurrentChapterName() {
                chapterName = chapter
            }
            
            // Get author name
            if let author = book.metadata.creators.first {
                authorName = author.name
            }
            
            // Sharing html and text
            html = "<html><body>"
            html += "<br /><hr> <p>\(htmlText)</p> <hr><br />"
            html += "<center><p style=\"color:gray\">"+readerConfig.localizedShareAllExcerptsFrom+"</p>"
            html += "<b>\(bookTitle)</b><br />"
            html += readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"
            if (bookShareLink != nil) { html += "<a href=\"\(bookShareLink!)\">\(bookShareLink!)</a>" }
            html += "</center></body></html>"
            text = "\(chapterName)\n\n“\(chapterText)” \n\n\(bookTitle) \nby \(authorName)"
            if (bookShareLink != nil) { text += " \n\(bookShareLink!)" }
            
            
            let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
            let shareItems = [act, ""] as [Any]
            let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
            activityViewController.excludedActivityTypes = [UIActivityType.print, UIActivityType.postToVimeo, UIActivityType.postToFacebook]
            
            // Pop style on iPad
            if let actv = activityViewController.popoverPresentationController {
                actv.barButtonItem = sender
            }
            
            present(activityViewController, animated: true, completion: nil)
        }
    }
    
    /**
     Sharing highlight method.
    */
    func shareHighlight(_ string: String, rect: CGRect) {
        
        var subject = readerConfig.localizedShareHighlightSubject
        var html = ""
        var text = ""
        var bookTitle = ""
        var chapterName = ""
        var authorName = ""
        
        // Get book title
        if let title = book.title() {
            bookTitle = title
            subject += " “\(title)”"
        }
        
        // Get chapter name
        if let chapter = getCurrentChapterName() {
            chapterName = chapter
        }
        
        // Get author name
        if let author = book.metadata.creators.first {
            authorName = author.name
        }
        
        // Sharing html and text
        html = "<html><body>"
        html += "<br /><hr> <p>\(chapterName)</p>"
        html += "<p>\(string)</p> <hr><br />"
        html += "<center><p style=\"color:gray\">"+readerConfig.localizedShareAllExcerptsFrom+"</p>"
        html += "<b>\(bookTitle)</b><br />"
        html += readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"
        if (bookShareLink != nil) { html += "<a href=\"\(bookShareLink!)\">\(bookShareLink!)</a>" }
        html += "</center></body></html>"
        text = "\(chapterName)\n\n“\(string)” \n\n\(bookTitle) \nby \(authorName)"
        if (bookShareLink != nil) { text += " \n\(bookShareLink!)" }
        
        
        let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
        let shareItems = [act, ""] as [Any]
        let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [UIActivityType.print, UIActivityType.postToVimeo, UIActivityType.postToFacebook]
        
        // Pop style on iPad
        if let actv = activityViewController.popoverPresentationController {
            actv.sourceView = currentPage
            actv.sourceRect = rect
        }
        
        present(activityViewController, animated: true, completion: nil)
    }
    
    // MARK: - ScrollView Delegate
    
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrolling = true
        clearRecentlyScrolled()
        recentlyScrolled = true
        pointNow = scrollView.contentOffset
        
        // Disallowing user to scroll
        currentPage.webView.scrollView.isUserInteractionEnabled = false
        collectionView.isUserInteractionEnabled = false
        
        if let currentPage = currentPage {
            currentPage.webView.createMenu(true)
            currentPage.webView.setMenuVisible(false)
        }
        
        scrollScrubber.scrollViewWillBeginDragging(scrollView)
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if !navigationController!.isNavigationBarHidden {
            toggleBars()
        }
        
        scrollScrubber.scrollViewDidScroll(scrollView)
        
        // Update current reading page
        if scrollView is UICollectionView {} else {
            let pageSize = isVerticalDirection(pageHeight, pageWidth)
            
            if let page = currentPage
                , page.webView.scrollView.contentOffset.forDirection()+pageSize! <= page.webView.scrollView.contentSize.forDirection() {
                let webViewPage = pageForOffset(page.webView.scrollView.contentOffset.forDirection(), pageHeight: pageSize!)
                if pageIndicatorView.currentPage != webViewPage {
                    pageIndicatorView.currentPage = webViewPage
                }
                // TODO: webviewPageDidChanged
            }
        }
        
        scrollDirection = scrollView.contentOffset.forDirection() < pointNow.forDirection() ? .negative() : .positive()
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        // Removing offsets for orientations
        print("Removing offsets for both orientations")
        saveOffset(forOrientation: .portrait, offset: nil)
        saveOffset(forOrientation: .landscapeLeft, offset: nil)
        
        // Allowing user to scroll again
        currentPage.webView.scrollView.isUserInteractionEnabled = true
        collectionView.isUserInteractionEnabled = true
        
        if scrollView is UICollectionView {
            if totalPages > 0 { updateCurrentPage() }
        } else {
            let pageSize = isVerticalDirection(pageHeight, pageWidth)
            
            if let page = currentPage
                , page.webView.scrollView.contentOffset.forDirection()+pageSize! <= page.webView.scrollView.contentSize.forDirection() {
                let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
                let webViewPage = pageForOffset(page.webView.scrollView.contentOffset.forDirection(), pageHeight: pageSize!)
                let pageState = ReaderState(current: webViewPage, total: totalWebviewPages)
                FolioReader.sharedInstance.readerContainer.webviewPageDidChanged(pageState)
            }
        }
        
        scrollScrubber.scrollViewDidEndDecelerating(scrollView)
    }
    
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        recentlyScrolledTimer = Timer(timeInterval:recentlyScrolledDelay, target: self, selector: #selector(FolioReaderCenter.clearRecentlyScrolled), userInfo: nil, repeats: false)
        RunLoop.current.add(recentlyScrolledTimer, forMode: RunLoopMode.commonModes)
    }

    func clearRecentlyScrolled() {
        if(recentlyScrolledTimer != nil) {
            recentlyScrolledTimer.invalidate()
            recentlyScrolledTimer = nil
        }
        recentlyScrolled = false
    }

    open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollScrubber.scrollViewDidEndScrollingAnimation(scrollView)
    }
    
    
    // MARK: NavigationBar Actions
    
    func closeReader(_ sender: UIBarButtonItem) {
        FolioReader.close()
        dismiss()
    }
    
    /**
     Present chapter list
     */
    func presentChapterList(_ sender: UIBarButtonItem) {
        FolioReader.saveReaderState()
        
        let chapter = FolioReaderChapterList()
        chapter.delegate = self
        let highlight = FolioReaderHighlightList()
        
        let pageController = PageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options:nil)
        pageController.viewControllerOne = chapter
        pageController.viewControllerTwo = highlight
        pageController.segmentedControlItems = ["Contents", readerConfig.localizedHighlightsTitle]
        
        let nav = UINavigationController(rootViewController: pageController)
        present(nav, animated: true, completion: nil)
    }
    
    /**
     Present fonts and settings menu
     */
    func presentFontsMenu() {
        FolioReader.saveReaderState()
        hideBars()
        
        let menu = FolioReaderFontsMenu()
        menu.modalPresentationStyle = .custom

        animator = ZFModalTransitionAnimator(modalViewController: menu)
        animator.isDragable = false
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = ZFModalTransitonDirection.bottom

        menu.transitioningDelegate = animator
        present(menu, animated: true, completion: nil)
    }

    /**
     Present audio player menu
     */
    func presentPlayerMenu(_ sender: UIBarButtonItem) {
        FolioReader.saveReaderState()
        hideBars()

        let menu = FolioReaderPlayerMenu()
        menu.modalPresentationStyle = .custom

        animator = ZFModalTransitionAnimator(modalViewController: menu)
        animator.isDragable = true
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = ZFModalTransitonDirection.bottom

        menu.transitioningDelegate = animator
        present(menu, animated: true, completion: nil)
    }
}

// MARK: FolioPageDelegate

extension FolioReaderCenter: FolioReaderPageDelegate {
    
    func pageDidLoad(_ page: FolioReaderPage) {
        if let position = FolioReader.defaults.value(forKey: kBookId) as? NSDictionary {
            let pageNumber = position["pageNumber"]! as! Int
            var pageOffset: CGFloat = 0
            
            if let offset = isVerticalDirection(position["pageOffsetY"], position["pageOffsetX"]) as? CGFloat {
                pageOffset = offset
            }
            
            if isFirstLoad {
                updateCurrentPage(page)
                isFirstLoad = false
                
                if currentPageNumber == pageNumber && pageOffset > 0 {
                    page.scrollPageToOffset(pageOffset, animated: false)
                }
            }
            
        } else if isFirstLoad {
            updateCurrentPage(page)
            isFirstLoad = false
        }
        
        // Go to fragment if needed
        if let fragmentID = tempFragment , fragmentID != "" && currentPage != nil {
            currentPage.handleAnchor(fragmentID, avoidBeginningAnchors: true, animated: true)
            tempFragment = nil
        }
    }
}

// MARK: FolioReaderChapterListDelegate

extension FolioReaderCenter: FolioReaderChapterListDelegate {
    
    func chapterList(_ chapterList: FolioReaderChapterList, didSelectRowAtIndexPath indexPath: IndexPath, withTocReference reference: FRTocReference) {
        let item = findPageByResource(reference)
        
        if item < totalPages-1 {
            let indexPath = IndexPath(row: item, section: 0)
            changePageWith(indexPath: indexPath, animated: false, completion: { () -> Void in
                self.updateCurrentPage()
            })
            tempReference = reference
        } else {
            print("Failed to load book because the requested resource is missing.")
        }
    }
    
    func chapterList(didDismissedChapterList chapterList: FolioReaderChapterList) {
        updateCurrentPage()
        
        // Move to #fragment
        if let reference = tempReference {
            if let fragmentID = reference.fragmentID , fragmentID != "" && currentPage != nil {
                currentPage.handleAnchor(reference.fragmentID!, avoidBeginningAnchors: true, animated: true)
            }
            tempReference = nil
        }
    }
}

@objc public protocol FolioReaderCenterDelegate {
    /**
     Called after `FolioReaderCenter.reloadData()` is called.
     
     - precondition: `FolioReaderCenter.reloadData()` called.
     */
    @objc optional func center(didReloadData center: FolioReaderCenter)
}
