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

/// Protocol which is used from `FolioReaderCenter`s.
@objc public protocol FolioReaderCenterDelegate: class {
    
    /**
     Notifies that a page appeared. This is triggered is a page is chosen and displayed.
     
     - parameter page: The appeared page
     */
    @objc optional func pageDidAppear(_ page: FolioReaderPage)
    
    /**
     Passes and returns the HTML content as `String`. Implement this method if you want to modify the HTML content of a `FolioReaderPage`.
     
     - parameter page: The `FolioReaderPage`
     - parameter htmlContent: The current HTML content as `String`
     
     - returns: The adjusted HTML content as `String`. This is the content which will be loaded into the given `FolioReaderPage`
     */
    @objc optional func htmlContentForPage(_ page: FolioReaderPage, htmlContent: String) -> String
    
    /**
     Notifies that the page's reading time did changed
     
     - parameter page: The appeared page
     - parameter time: The reaminder reading time
     */
    @objc optional func center(chapter: FolioReaderPage, readingTimeDidChanged readingTime: Int)
    
    // Refactored from pageDidChanged
    @objc optional func center(pageDidChanged page: FolioReaderPage, current: Int, total: Int)
    
    // Refactored from chapterDidChanged
    @objc optional func center(chapterDidChanged page: FolioReaderPage, current: Int, total: Int)
    
    // Refactored from chapterNameDidChanged
    @objc optional func center(chapter: FolioReaderPage, nameDidChanged name: String)
    
    // Refactored from highlightWasPersisted
    @objc optional func center(chapter: FolioReaderPage, highlightWasPersisted highlight: Highlight)
    
    // Refactored from highlightWasUpdated
    @objc optional func center(chapter: FolioReaderPage, highlightWasUpdated highlight: Highlight)
    
    // Refactored from highlightWasRemoved
    @objc optional func center(chapter: FolioReaderPage, highlightWasRemoved highlight: Highlight)
    
    @objc optional func center(searchDidJumped toResult: Int, ofTotal total: Int)
    
    @objc optional func center(willHideBars page: FolioReaderPage)
    
}

open class FolioReaderCenter: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    var collectionView: UICollectionView!
    let collectionViewLayout = UICollectionViewFlowLayout()
    var loadingView: UIActivityIndicatorView!
    var pages: [String]!
    var totalPages: Int!
    var tempFragment: String?
    
    var highlightsToSync: [Highlight]?
    var annotationsToSync: [Highlight]?
    
    var currentPage: FolioReaderPage!
    open var delegate: FolioReaderCenterDelegate?
    
    var animator: ZFModalTransitionAnimator!
    var pageIndicatorView: FolioReaderPageIndicator!
    var bookShareLink: String?
    
    var recentlyScrolled = false
    var recentlyScrolledDelay = 2.0 // 2 second delay until we clear recentlyScrolled
    var recentlyScrolledTimer: Timer!
    var scrollScrubber: ScrollScrubber?
    
    fileprivate var screenBounds: CGRect!
    fileprivate var pointNow = CGPoint.zero
    fileprivate var pageIndicatorHeight: CGFloat = 20
    fileprivate var pageOffsetRate: CGFloat = 0
    fileprivate var internalOffsetPortrait: CGPoint?
    fileprivate var internalOffsetLandscape: CGPoint?
    fileprivate var tempReference: FRTocReference?
    fileprivate var isFirstLoad = true
    fileprivate var currentOrientation: UIInterfaceOrientation?
    fileprivate var currentWebViewScrollPositions = [Int: CGPoint]()
    
    open var isFirstLoadOrientation = true
    var lastContentOffset : CGFloat!
    
    
    var onChangePageDelayed: ((FolioReaderCenter) -> ())?
    
    // MARK: - Init
    
    init() {
        super.init(nibName: nil, bundle: Bundle.frameworkBundle())
        initialization()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialization()
    }
    
    /**
     Common Initialization
     */
    fileprivate func initialization() {
        
        if (readerConfig.hideBars == true) {
            self.pageIndicatorHeight = 0
        }
        
        totalPages = book.spine.spineReferences.count
        
        // Loading indicator
        let style: UIActivityIndicatorViewStyle = isNight(.white, .gray)
        loadingView = UIActivityIndicatorView(activityIndicatorStyle: style)
        loadingView.hidesWhenStopped = true
        loadingView.startAnimating()
        view.addSubview(loadingView)
    }
    
    // MARK: - View life cicle
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        screenBounds = self.view.frame
        setPageSize(UIApplication.shared.statusBarOrientation)
        
        // Layout
        collectionViewLayout.sectionInset = UIEdgeInsets.zero
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.scrollDirection = .direction()
        
        let background = isNight(readerConfig.nightModeBackground, UIColor.white)
        view.backgroundColor = background
        
        // CollectionView
        collectionView = UICollectionView(frame: screenBounds, collectionViewLayout: collectionViewLayout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.bounces = false
        collectionView.backgroundColor = background
        collectionView.decelerationRate = UIScrollViewDecelerationRateFast
        enableScrollBetweenChapters(scrollEnabled: true)
        view.addSubview(collectionView)
        
        if #available(iOS 10.0, *) {
            collectionView.isPrefetchingEnabled = false
        }
        
        // Register cell classes
        collectionView!.register(FolioReaderPage.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Configure navigation bar and layout
        automaticallyAdjustsScrollViewInsets = false
        extendedLayoutIncludesOpaqueBars = true
        configureNavBar()
        
        // Page indicator view
        pageIndicatorView = FolioReaderPageIndicator(frame: self.frameForPageIndicatorView())
        if let pageIndicatorView = pageIndicatorView {
            view.addSubview(pageIndicatorView)
        }
        
        scrollScrubber = ScrollScrubber(frame: self.frameForScrollScrubber())
        scrollScrubber?.delegate = self
        if let scrollScrubber = scrollScrubber {
            view.addSubview(scrollScrubber.slider)
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let navController = self.navigationController as! FolioReaderNavigationController
        navController.restoreNavigationBar()
        
        // Update pages
        pagesForCurrentPage(currentPage)
        pageIndicatorView?.reloadView(true)
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        screenBounds = view.frame
        loadingView.center = view.center
        
        setPageSize(UIApplication.shared.statusBarOrientation)
        updateSubviewFrames()
    }
    
    /**
     Enable or disable the scrolling between chapters (`FolioReaderPage`s). If this is enabled it's only possible to read the current chapter. If another chapter should be displayed is has to be triggered programmatically with `changePageWith`.
     
     - parameter scrollEnabled: `Bool` which enables or disables the scrolling between `FolioReaderPage`s.
     */
    open func enableScrollBetweenChapters(scrollEnabled: Bool) {
        self.collectionView.isScrollEnabled = scrollEnabled
    }
    
    fileprivate func updateSubviewFrames() {
        self.pageIndicatorView?.frame = self.frameForPageIndicatorView()
        self.scrollScrubber?.frame = self.frameForScrollScrubber()
    }
    
    fileprivate func frameForPageIndicatorView() -> CGRect {
        return CGRect(x: 0, y: view.frame.height-pageIndicatorHeight, width: view.frame.width, height: pageIndicatorHeight)
    }
    
    fileprivate func frameForScrollScrubber() -> CGRect {
        let scrubberY: CGFloat = ((readerConfig.shouldHideNavigationOnTap == true || readerConfig.hideBars == true) ? 50 : 74)
        return CGRect(x: pageWidth + 10, y: scrubberY, width: 40, height: pageHeight - 100)
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
    
    open func search(withTerm term: String) {
        currentPage.webView.highlightAllOccurrences(ofString: term)
    }
    
    open func clearSearch() {
        currentPage.webView.js("clearMarks()")
    }
    
    open func skipToNextSearchResult() {
        currentPage.webView.js("skipToNextMark()")
    }
    
    open func skipToPreviousSearchResult() {
        currentPage.webView.js("skipToPreviousMark()")
    }

    func reloadData() {
        loadingView.stopAnimating()
        bookShareLink = readerConfig.localizedShareWebLink
        totalPages = book.spine.spineReferences.count

        collectionView.reloadData()
        
        if let key = kBookId {
            if let position = FolioReader.defaults.value(forKey: key) as? NSDictionary,
                let pageNumber = position["pageNumber"] as? Int , pageNumber > 0 {
                changePageWith(page: pageNumber)
                currentPageNumber = pageNumber
                print("a")
                return
            }
        }
        
        currentPageNumber = 1
        print("b")
    }
    
    
    
    // MARK: Status bar and Navigation bar
    
    public func hideBars() {
        if readerConfig.shouldHideNavigationOnTap == false { return }

        let shouldHide = true
        FolioReader.sharedInstance.readerContainer.shouldHideStatusBar = shouldHide
        delegate?.center?(willHideBars: currentPage)
        
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
        currentPage.webView.js("setFontName('\(name.fontName())')")
    }
    
    open func setFontSize(_ style: FolioReaderFontSize) {
        print("setFontSize('\(style.fontSize())')")
        FolioReader.sharedInstance.currentFontSize = style.rawValue
        currentPage.webView.js("setFontSize('\(style.fontSize())')")
    }
    
    open func setTextAlignment(_ style: FolioReaderTextAlignemnt) {
        print("setTextAlignment('\(style.textAlignment())')")
        FolioReader.sharedInstance.currentTextAlignement = style.rawValue
        currentPage.webView.js("setTextAlignment('\(style.textAlignment())')")
    }
    
    // MARK: UICollectionViewDataSource
    
    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalPages
    }
    
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    }

    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        print("\n### willDisplayCell ###")
        let chapter = cell as! FolioReaderPage
        
        if readerConfig.scrollDirection != .horizontalWithVerticalContent {
            chapter.enableInteraction()
            
            print("Is scrolling back: \(scrollDirection == .negative())")
            print("Is scrolling: \(isScrolling)")
            if scrollDirection == .negative() && isScrolling {
                chapter.scrollPageToBottom()
            } else {
                chapter.scrollPageToOffset(0.0, animated: false)
            }
        }
        
        print("### willDisplayCell ###\n")
    }
    
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! FolioReaderPage
        
        cell.centerDelegate = delegate
        cell.delegate = self
        cell.pageNumber = indexPath.row+1
        cell.webView.scrollView.delegate = self
        cell.webView.setupScrollDirection()
        cell.webView.frame = cell.webViewFrame()
        cell.backgroundColor = UIColor.clear
        
        // Configure the cell
        if let resource = book.spine.spineReferences[indexPath.row].resource, let html = epubToHtml(resource) {
            cell.loadHTMLString(html, baseURL: URL(fileURLWithPath: (NSString(string: resource.fullHref)).deletingLastPathComponent))
        }
        
        return cell
    }
    
    open func epubToHtml(_ resource: FRResource) -> String? {
        var html = try? String(contentsOfFile: (resource.fullHref)!, encoding: String.Encoding.utf8)
        let mediaOverlayStyleColors = "\"\(readerConfig.mediaOverlayColor.hexString(false))\", \"\(readerConfig.mediaOverlayColor.highlightColor().hexString(false))\""
        
        // Inject CSS
        let annotationSVGPath = Bundle.frameworkBundle().path(forResource: "btn_anot", ofType: "svg")
        let discussionSVGPath = Bundle.frameworkBundle().path(forResource: "btn_disc", ofType: "svg")
        
        let jqueryJsFilePath = Bundle.frameworkBundle().path(forResource: "jquery-3.1.1.min", ofType: "js")
        let markJsFilePath = Bundle.frameworkBundle().path(forResource: "mark.min", ofType: "js")
        let jsFilePath = Bundle.frameworkBundle().path(forResource: "bridge", ofType: "js")
        let annotationsJsFilePath = Bundle.frameworkBundle().path(forResource: "annotation", ofType: "js")
        
        let cssFilePath = Bundle.frameworkBundle().path(forResource: "Style", ofType: "css")
        let cssTag = "<link rel=\"stylesheet\" type=\"text/css\" href=\"\(cssFilePath!)\">"
        
        let jsTag = "<script type=\"text/javascript\" src=\"\(jqueryJsFilePath!)\"></script>" +
                    "<script type=\"text/javascript\" src=\"\(markJsFilePath!)\"></script>" +
                    "<script type=\"text/javascript\" src=\"\(jsFilePath!)\"></script>" +
                    "<script type=\"text/javascript\">setMediaOverlayStyleColors(\(mediaOverlayStyleColors))</script>"
        
        let toInject = "\n\(cssTag)\n\(jsTag)\n</head>"
//        let toInject = "\n\(cssTag)\n\(jsTag)\n</head><annotation id=\"10\"></annotation>A Imunologia faz parte do aprendizado em medicina há alguns anos,<annotation id=\"20\" data-type=\"discussion\"></annotation> mas o conhecimento e o aprofundamento tornaram-se essenciais no século 21 para qualquer médico. <annotation id=\"30\"></annotation>As aplicações são inúmeras, e para citar alguns exemplos temos tratamentos com vacinas, imunomoduladores, terapia de supressão viral e uso de marcadores imunológicos para detecção precoce de doenças. Da mesma maneira, as áreas são diversas, como Infectologia, Reumatologia, Gastroenterologia, Dermatologia e Cirurgia do Aparelho Digestivo. O objetivo deste capítulo é relembrarnoções básicas de Imunologia e sua aplicabilidade prática, direcionando para os assuntos cobrados nas provas de Residência Médica.<br/><br/>"
        
        html = html?.replacingOccurrences(of: "</head>", with: toInject)
        
        let searchButtons = "<button id=\"previous_search_result_button\"data-search=\"prev\" style=\"visibility: hidden\">Anterior</button>" +
                            "<button id=\"next_search_result_button\"data-search=\"next\" style=\"visibility: hidden\">Próximo</button>"
        let annotationsTag = "<script type=\"text/javascript\">var annotationSvg = \"\(annotationSVGPath!)\"; var discussionSvg = \"\(discussionSVGPath!)\";</script>\n" +
                             "<script type=\"text/javascript\" src=\"\(annotationsJsFilePath!)\"></script>"

        html = html?.replacingOccurrences(of: "</body>", with: "\(searchButtons)\n\(annotationsTag)\n</body>")
        
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
        
        return html?.replacingOccurrences(of: "<html ", with: "<html class=\"\(classes)\" style=\"\(style)\"")
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        return CGSize(width: pageWidth, height: pageHeight)
    }
    
    // MARK: - Device rotation
    
    override open func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        adjustRotate(to: toInterfaceOrientation, duration: duration)
    }
    
    open func adjustRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval){
        
        guard FolioReader.sharedInstance.isReaderReady else { return }
        
        setPageSize(toInterfaceOrientation)
        updateCurrentPage()
        
        if (self.currentOrientation == nil || (self.currentOrientation?.isPortrait != toInterfaceOrientation.isPortrait)) {
            
            var pageIndicatorFrame = pageIndicatorView?.frame
            pageIndicatorFrame?.origin.y = ((screenBounds.size.height < screenBounds.size.width) ? (self.collectionView.frame.height - pageIndicatorHeight) : (self.collectionView.frame.width - pageIndicatorHeight))
            pageIndicatorFrame?.origin.x = 0
            pageIndicatorFrame?.size.width = ((screenBounds.size.height < screenBounds.size.width) ? (self.collectionView.frame.width) : (self.collectionView.frame.height))
            pageIndicatorFrame?.size.height = pageIndicatorHeight
            
            var scrollScrubberFrame = scrollScrubber?.slider.frame;
            scrollScrubberFrame?.origin.x = ((screenBounds.size.height < screenBounds.size.width) ? (view.frame.width - 100) : (view.frame.height + 10))
            scrollScrubberFrame?.size.height = ((screenBounds.size.height < screenBounds.size.width) ? (self.collectionView.frame.height - 100) : (self.collectionView.frame.width - 100))
            
            self.collectionView.collectionViewLayout.invalidateLayout()
            
            UIView.animate(withDuration: duration, animations: {
                
                // Adjust page indicator view
                if let pageIndicatorFrame = pageIndicatorFrame {
                    self.pageIndicatorView?.frame = pageIndicatorFrame
                    self.pageIndicatorView?.reloadView(true)
                }
                
                // Adjust scroll scrubber slider
                if let scrollScrubberFrame = scrollScrubberFrame {
                    self.scrollScrubber?.slider.frame = scrollScrubberFrame
                }
                
                // Adjust collectionView
                self.collectionView.contentSize = isDirection(
                    CGSize(width: pageWidth, height: pageHeight * CGFloat(self.totalPages)),
                    CGSize(width: pageWidth * CGFloat(self.totalPages), height: pageHeight),
                    CGSize(width: pageWidth * CGFloat(self.totalPages), height: pageHeight)
                )
                self.collectionView.setContentOffset(self.frameForPage(page: currentPageNumber).origin, animated: false)
                self.collectionView.collectionViewLayout.invalidateLayout()
                
                // Adjust internal page offset
                guard let currentPage = self.currentPage else { return }
                let pageScrollView = currentPage.webView.scrollView
                self.pageOffsetRate = pageScrollView.contentOffset.forDirection() / pageScrollView.contentSize.forDirection()
                
                // Salvando o offset da orientação atual
                if readerConfig.scrollDirection == .horizontal {
                    self.saveOffset(forOrientation: UIApplication.shared.statusBarOrientation, offset: pageScrollView.contentOffset)
                    self.pageOffsetRate = pageScrollView.contentOffset.forDirection() / pageScrollView.contentSize.forDirection()
                }
            })
        }
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
        guard FolioReader.sharedInstance.isReaderReady else { return }
        guard let currentPage = currentPage else { return }
        
        // Update pages
        pagesForCurrentPage(currentPage)
        currentPage.refreshPageMode()
        
        scrollScrubber?.setSliderVal()
        
        // After rotation fix internal page offset
        var pageOffset = currentPage.webView.scrollView.contentSize.forDirection() * pageOffsetRate
        
        // Fix the offset for paged scroll
        if readerConfig.scrollDirection == .horizontal {
            let page = round(pageOffset / pageWidth)
            pageOffset = page * pageWidth
        }
        
        let pageOffsetPoint = isDirection(CGPoint(x: 0, y: pageOffset), CGPoint(x: pageOffset, y: 0))
        currentPage.webView.scrollView.setContentOffset(pageOffsetPoint, animated: true)
    }
    
    override open func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        guard FolioReader.sharedInstance.isReaderReady else { return }
        
        self.collectionView.scrollToItem(at: IndexPath(row: currentPageNumber - 1, section: 0), at: UICollectionViewScrollPosition(), animated: false)
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
                pageWidth = self.view.frame.width
                pageHeight = self.view.frame.height
            } else {
                pageWidth = self.view.frame.height
                pageHeight = self.view.frame.width
            }
        } else {
            if screenBounds.size.width > screenBounds.size.height {
                pageWidth = self.view.frame.width
                pageHeight = self.view.frame.height
            } else {
                pageWidth = self.view.frame.height
                pageHeight = self.view.frame.width
            }
        }
    }
    
    func updateCurrentPage(_ completion: (() -> Void)? = nil) {
        updateCurrentPage(nil) { () -> Void in
            completion?()
        }
    }
    
    func updateCurrentPage(_ page: FolioReaderPage!, completion: (() -> Void)? = nil) {
        print("\n### updateCurrentPage ###")
        if let page = page {
            currentPage = page
            previousPageNumber = page.pageNumber-1
            currentPageNumber = page.pageNumber
        } else {
            let currentIndexPath = getCurrentIndexPath()
            currentPage = self.collectionView.cellForItem(at: currentIndexPath) as? FolioReaderPage
            
            previousPageNumber = currentIndexPath.row
            currentPageNumber = currentIndexPath.row+1
        }
        
        nextPageNumber = currentPageNumber + 1 <= totalPages ? currentPageNumber + 1 : currentPageNumber
        
        print("Previous page number: \(previousPageNumber!)")
        print("Current page number: \(currentPageNumber!)")
        print("Next page number: \(nextPageNumber!)")
        //TODO validar de onde vem o currenPage, fixed temporario
        if currentPage != nil {
            currentPage.webView.becomeFirstResponder()
            scrollScrubber?.setSliderVal()
            // Set navigation title
            if let chapterName = getCurrentChapterName() {
                title = chapterName
                delegate?.center?(chapter: currentPage, nameDidChanged: chapterName)
            } else { title = ""}
            
            // Updating remainder reading time
            var readingTime = 0
            if let readingTimeString = currentPage.webView.js("getReadingTime()") {
                readingTime = Int(readingTimeString)!
            }
            pageIndicatorView?.totalMinutes = readingTime
            delegate?.center?(chapter: currentPage, readingTimeDidChanged: readingTime)
            
            pagesForCurrentPage(currentPage)
            delegate?.pageDidAppear?(currentPage)
        }
        currentPage.annotationSync = true
        
      
        print("### updateCurrentPage ###\n")
        
        completion?()
    }
    
    func pagesForCurrentPage(_ page: FolioReaderPage?) {
        guard let page = page else { return }
        
        let pageSize = isDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(page.webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.forDirection(), pageHeight: pageSize!)
        
        pageIndicatorView.totalPages = totalWebviewPages
        pageIndicatorView.currentPage = webViewPage
        print("Updating folio reader current page indicator to \(webViewPage)/\(totalWebviewPages)")
        
        var chapterState = ReaderState(current: currentPageNumber, total: totalPages)
        var pageState = ReaderState(current: webViewPage, total: totalWebviewPages)

        delegate?.center?(chapterDidChanged: currentPage, current: chapterState.current, total: chapterState.total)
        delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
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
            case .right:
                if (first as NSIndexPath).compare(last) == .orderedAscending {
                    indexPath = first
                } else {
                    indexPath = last
                }
            default:
                if (first as NSIndexPath).compare(last) == .orderedDescending {
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
        return isDirection(
            CGRect(x: 0, y: pageHeight * CGFloat(page-1), width: pageWidth, height: pageHeight),
            CGRect(x: pageWidth * CGFloat(page-1), y: 0, width: pageWidth, height: pageHeight)
        )
    }
    
    open func changePageWith(page: Int, animated: Bool = false, completion: (() -> Void)? = nil) {
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
    
    open func skipToFirstChapter() {
        let pageSize = isDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageSize!)
        
        if currentPage.pageNumber == 1 {
            let pageState = ReaderState(current: 1, total: totalWebviewPages)
            FolioReader.sharedInstance.readerContainer.webviewPageDidChanged(pageState)
            delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
            currentPage.scrollPageToOffset(0.0, animated: true)
        } else {
//            changeToPage(1, scrolling: false)
            changePageWith(page: 1)
        }
    }
    
    open func skipToSecondChapter() {
        let pageSize = isDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageSize!)
        
        if currentPage.pageNumber == 2 {
            let pageState = ReaderState(current: 2, total: totalWebviewPages)
            FolioReader.sharedInstance.readerContainer.webviewPageDidChanged(pageState)
            delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
            currentPage.scrollPageToOffset(0.0, animated: true)
        } else {
//            changeToPage(2, scrolling: false)
            changePageWith(page: 2)
        }
    }
    
    open func skipToPage(_ page: Int) {
        let pageSize = isDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageSize!)
        
        let currentOffset = currentPage.webView.scrollView.contentOffset
        print("scrolling webview \(page)/\(totalPages)")
        let pageState = ReaderState(current: page + 1, total: totalWebviewPages)
        
        delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
        currentPage.scrollPageToOffset(pageSize! * CGFloat(page), animated: true)
    }
    
    open func skipPageForward(_ skipMode: FolioReaderSkipPageMode = .hybrid) {
        print("\n### skipPageForward ###")
        guard currentPage.webView.isUserInteractionEnabled else { return }
        
        let pageSize = isDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageSize!)
        
        // Disallowing user to scroll
        currentPage.disableInteraction()
        
        switch skipMode {
        case .hybrid:
            print("Hybrid Mode")
            if webViewPage < totalWebviewPages {
                print("Skipping on Webview page (\(webViewPage)/\(totalWebviewPages))")
                print("### skipPageForward ###\n")
                
                let currentOffset = currentPage.webView.scrollView.contentOffset
                let pageState = ReaderState(current: webViewPage + 1, total: totalWebviewPages)
                delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
                currentPage.scrollPageToOffset(currentOffset.x + pageSize!, animated: true)
            } else if nextPageNumber <= totalPages {
                print("Skipping on Collectionview chapter (\(currentPageNumber)\(totalPages))")
                print("### skipPageForward ###\n")
                
//                changeToPage(nextPageNumber, scrolling: false)
                changePageWith(page: nextPageNumber)
            }
            break
        case .chapter:
            guard nextPageNumber <= totalPages else { return }
            print("Chapter mode")
            print("Skipping on Collectionview chapter (\(currentPageNumber)\(totalPages))")
            print("### skipPageForward ###\n")
            
//            changeToPage(nextPageNumber, scrolling: false)
            changePageWith(page: nextPageNumber)
            break
        case .page:
            guard webViewPage < totalWebviewPages else { return }
            print("Page mode")
            print("Skipping on Webview page (\(webViewPage)/\(totalWebviewPages))")
            print("### skipPageForward ###\n")
            
            let currentOffset = currentPage.webView.scrollView.contentOffset
            let pageState = ReaderState(current: webViewPage + 1, total: totalWebviewPages)
            delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
            
            currentPage.scrollPageToOffset(currentOffset.x + pageSize!, duration: 0.1)
            
            break
        }
    }
    
    open func skipPageBackward(_ skipMode: FolioReaderSkipPageMode = .hybrid) {
        print("\n### skipPageBackward ###")
        guard currentPage.webView.isUserInteractionEnabled else { return }
        
        let pageSize = isDirection(pageHeight, pageWidth)
        let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
        let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageSize!)
        
        // Disallowing user to scroll
        currentPage.disableInteraction()
        
        switch skipMode {
        case .hybrid:
            print("Hybrid Mode")
            if webViewPage > 1 {
                print("Skipping on Webview page (\(webViewPage)/\(totalWebviewPages))")
                print("### skipPageBackward ###\n")
                
                let currentOffset = currentPage.webView.scrollView.contentOffset
                let pageState = ReaderState(current: webViewPage - 1, total: totalWebviewPages)
                delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
                currentPage.scrollPageToOffset(currentOffset.x - pageSize!, animated: true)
            } else if previousPageNumber >= 1 {
                print("Skipping on Collectionview chapter (\(currentPageNumber)\(totalPages))")
                print("### skipPageBackward ###\n")
                
//                changeToPage(previousPageNumber, scrolling: true)
                changePageWith(page: previousPageNumber)
            } else {
                currentPage.enableInteraction()
            }
            break
        case .chapter:
            guard previousPageNumber >= 1 else { return }
            
            print("Chapter mode")
            print("Skipping on Collectionview chapter (\(currentPageNumber)\(totalPages))")
            print("### skipPageBackward ###\n")
            
//            changeToPage(previousPageNumber, scrolling: false)
            changePageWith(page: previousPageNumber)
            break
        case .page:
            guard webViewPage > 1 else { return }
            print("Page mode")
            print("Skipping on Webview page (\(webViewPage)/\(totalWebviewPages))")
            print("### skipPageBackward ###\n")
            
            let currentOffset = currentPage.webView.scrollView.contentOffset
            let pageState = ReaderState(current: webViewPage - 1, total: totalWebviewPages)
            delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
            
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
        
        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: UIViewAnimationOptions(), animations: { () -> Void in
            self.collectionView.scrollToItem(at: indexPath, at: .direction(), animated: false)
        }) { (finished: Bool) -> Void in
            completion?()
        }
    }
    
//    func changeToPage(_ page: Int, scrolling: Bool = true, animated: Bool = false, completion: (() -> Void)? = nil) {
//        if page > 0 && page-1 < totalPages {
//            let indexPath = IndexPath(row: page-1, section: 0)
//            changeToPage(atIndexPath: indexPath, scrolling: scrolling, animated: animated, completion: { () -> Void in
//                self.updateCurrentPage({ () -> Void in
//                    completion?()
//                })
//            })
//        }
//    }
//    
//    func changeToPage(atIndexPath indexPath: IndexPath, scrolling: Bool = true, animated: Bool = false, completion: (() -> Void)? = nil) {
//        guard indexPathIsValid(indexPath) else {
//            print("ERROR: Attempt to scroll at invalid index path")
//            completion?()
//            return
//        }
//        
//        pointNow = collectionView.contentOffset
//        
//        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: UIViewAnimationOptions(), animations: {
//            
//            self.collectionView.scrollToItem(at: indexPath, at: .direction(), animated: false)
//        }) { (finished: Bool) -> Void in
//            completion?()
//        }
//        
//    }
    
    func indexPathIsValid(_ indexPath: IndexPath) -> Bool {
        let section = indexPath.section
        let row = indexPath.row
        let lastSectionIndex = numberOfSections(in: collectionView) - 1
        
        //Make sure the specified section exists
        if section > lastSectionIndex {
            return false
        }
        
        let rowCount = self.collectionView(collectionView, numberOfItemsInSection: indexPath.section) - 1
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
            if book.flatTableOfContents != nil {
                for item in book.flatTableOfContents {
                    if let reference = book.spine.spineReferences[safe: currentPageNumber-1], let resource = item.resource
                        , resource == reference.resource {
                        return item.resource
                    }
                }
            } else {
                return nil
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
    
    open func getChapterName(with chapterNumber: Int) -> String? {
        if let toc = book.getTableOfContents(), chapterNumber - 1 < toc.count {
            let title = toc[chapterNumber - 1].title
            return title
        }
        return nil
    }
    
    // MARK: - Audio Playing

    func audioMark(href: String, fragmentID: String) {
        changePageWith(href: href, andAudioMarkID: fragmentID)
    }
    
    // MARK: - Highlight & Annotations
    
    open func clearSelectedHighlightId() {
        selectedHighlightId = nil
    }
    
    open func sync(highlights: [Highlight]?, annotations: [Highlight]?) {
        if let _ = currentPage {
            if let highlights = highlights {
                currentPage.insertHighlights(highlights)
            }
            
            if let annotations = annotations {
                currentPage.insertAnnotations(annotations)
            }
        } else {
            highlightsToSync = highlights
            annotationsToSync = annotations
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
        currentPage.disableInteraction()
        
        if let currentPage = currentPage {
            currentPage.webView.createMenu(options: true)
            currentPage.webView.setMenuVisible(false)
        }
        
        scrollScrubber?.scrollViewWillBeginDragging(scrollView)
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if !navigationController!.isNavigationBarHidden {
            hideBars()
        }
        
        scrollScrubber?.scrollViewDidScroll(scrollView)
        
        // Update current reading page
        if scrollView is UICollectionView {} else {
            let pageSize = isDirection(pageHeight, pageWidth)
            
            if let page = currentPage
                , page.webView.scrollView.contentOffset.forDirection()+pageSize! <= page.webView.scrollView.contentSize.forDirection() {
                let webViewPage = pageForOffset(page.webView.scrollView.contentOffset.forDirection(), pageHeight: pageSize!)
                
                if (readerConfig.scrollDirection == .horizontalWithVerticalContent),
                    let cell = ((scrollView.superview as? UIWebView)?.delegate as? FolioReaderPage) {
                    
                    let currentIndexPathRow = cell.pageNumber - 1
                    
                    // if the cell reload don't save the top position offset
                    if let oldOffSet = self.currentWebViewScrollPositions[currentIndexPathRow]
                    , (abs(oldOffSet.y - scrollView.contentOffset.y) > 100) {} else {
                        self.currentWebViewScrollPositions[currentIndexPathRow] = scrollView.contentOffset
                    }
                }
                
                if pageIndicatorView.currentPage != webViewPage {
                    pageIndicatorView.currentPage = webViewPage
                }
            }
        }
        
      
        if (pointNow.x > scrollView.contentOffset.x) {
            scrollDirection = .negative()
        }
        else  {
            scrollDirection = .positive()
        }
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isScrolling = false
        
        if readerConfig.scrollDirection != .horizontalWithVerticalContent {
            // Removing offsets for orientations
            print("Removing offsets for both orientations")
            saveOffset(forOrientation: .portrait, offset: nil)
            saveOffset(forOrientation: .landscapeLeft, offset: nil)
        }
        
        // Allowing user to scroll again
        currentPage.enableInteraction()
        
        if (readerConfig.scrollDirection == .horizontalWithVerticalContent),
            let cell = ((scrollView.superview as? UIWebView)?.delegate as? FolioReaderPage) {
            let currentIndexPathRow = cell.pageNumber - 1
            self.currentWebViewScrollPositions[currentIndexPathRow] = scrollView.contentOffset
        }
        
        if scrollView is UICollectionView {
            if totalPages > 0 { updateCurrentPage() }
        } else {
            let pageSize = isDirection(pageHeight, pageWidth)
            FolioReader.sharedInstance.readerContainer.updateChapterPosition(chapter: currentPage.pageNumber-1, position: Float(currentPage.webView.scrollView.contentOffset.y))
            if let page = currentPage
                , page.webView.scrollView.contentOffset.forDirection()+pageSize! <= page.webView.scrollView.contentSize.forDirection() {
                let totalWebviewPages = Int(ceil(currentPage.webView.scrollView.contentSize.forDirection()/pageSize!))
                let webViewPage = pageForOffset(page.webView.scrollView.contentOffset.forDirection(), pageHeight: pageSize!)
                let pageState = ReaderState(current: webViewPage, total: totalWebviewPages)
                delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
            }


        }
        
        scrollScrubber?.scrollViewDidEndDecelerating(scrollView)
    }
    
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        recentlyScrolledTimer = Timer(timeInterval:recentlyScrolledDelay, target: self, selector: #selector(FolioReaderCenter.clearRecentlyScrolled), userInfo: nil, repeats: false)
        RunLoop.current.add(recentlyScrolledTimer, forMode: RunLoopMode.commonModes)
        
        print("will Decelerate? \(decelerate)")
        isScrolling = decelerate
        // Allowing user to scroll again
        currentPage.enableInteraction()
    }

    func clearRecentlyScrolled() {
        if(recentlyScrolledTimer != nil) {
            recentlyScrolledTimer.invalidate()
            recentlyScrolledTimer = nil
        }
        recentlyScrolled = false
    }

    open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if readerConfig.scrollDirection != .horizontalWithVerticalContent {
            // Allowing user to scroll again
            currentPage.enableInteraction()
        }
        
        scrollScrubber?.scrollViewDidEndScrollingAnimation(scrollView)
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
        print("\n### pageDidLoad ###")
        
        var currentOffset = page.webView.scrollView.contentOffset
        if let position = FolioReader.defaults.value(forKey: kBookId) as? NSDictionary {
            let pageNumber = position["pageNumber"]! as! Int
            let offset = isDirection(position["pageOffsetY"], position["pageOffsetX"]) as? CGFloat
            let pageOffset = offset
//            
            print("Using offset saved on UserDefaults")
            print("Page offset: \(pageOffset)")
            
            if isFirstLoad {
                print("It's first time load, updating current page")
                updateCurrentPage(page)
                isFirstLoad = false
                
                if currentPageNumber == pageNumber && pageOffset! > CGFloat(0) {
                    page.scrollPageToOffset(pageOffset!, animated: false)
                    currentOffset = page.webView.scrollView.contentOffset
                    print("Scrolled to page offset. Webview's offset is \(currentOffset)")
                }
            } else if !isScrolling {
                let position = FolioReader.sharedInstance.readerContainer.getChapterPosition(chapter: page.pageNumber-1)
                page.scrollPageToOffset(CGFloat(position), animated: false)
                currentOffset = page.webView.scrollView.contentOffset
                print("Scrolled to page offset. Webview's offset is \(currentOffset)")
//                page.scrollPageToBottom()
            }
            
        } else if isFirstLoad {
            print("No offset saved on UserDefaults")
            print("It's first time load, updating current page")
            updateCurrentPage(page)
            isFirstLoad = false
        }
        
        // Go to fragment if needed
        if let fragmentID = tempFragment , fragmentID != "" && currentPage != nil {
            currentPage.handleAnchor(fragmentID, avoidBeginningAnchors: true, animated: true)
            tempFragment = nil
        }
        
        if (readerConfig.scrollDirection == .horizontalWithVerticalContent),
            let offsetPoint = self.currentWebViewScrollPositions[page.pageNumber - 1] {
            page.webView.scrollView.setContentOffset(offsetPoint, animated: false)
        }
        
        if let chapterName = getCurrentChapterName() {
            title = chapterName
            delegate?.center?(chapter: currentPage, nameDidChanged: chapterName)
        } else { title = ""}
        
        if let width = page.webView.js("document.body.scrollWidth"), let height = page.webView.js("document.body.scrollHeight") {
            let pageSize = isDirection(pageHeight, pageWidth)
            
            let jsContentSizeWidth = CGFloat(NumberFormatter().number(from: width)!)
            let jsContentSizeHeight = CGFloat(NumberFormatter().number(from: height)!)
            print("Got content size from javascript: (W:\(jsContentSizeWidth), H:\(jsContentSizeHeight))")
            
            print("javascript offset: \(currentOffset)")
            print("iOS webview offset: \(page.webView.scrollView.contentOffset)")
            
            let webViewContentSize = CGSize(width: jsContentSizeWidth, height: jsContentSizeHeight)
            
            let totalWebviewPages = Int(ceil(webViewContentSize.forDirection()/pageSize!))
            let webViewPage = pageForOffset(currentOffset.forDirection(), pageHeight: pageSize!)
            print("The page for the currentOffset in the chapter is \(webViewPage)/\(totalWebviewPages)")
            
            var chapterState = ReaderState(current: currentPageNumber, total: totalPages)
            var pageState = ReaderState(current: webViewPage, total: totalWebviewPages)
            
            delegate?.center?(chapterDidChanged: currentPage, current: chapterState.current, total: chapterState.total)
            delegate?.center?(pageDidChanged: currentPage, current: pageState.current, total: pageState.total)
        }
        
        isFirstLoadOrientation = false
        print("### pageDidLoad ###\n")
        
        if let finally = onChangePageDelayed {
            finally(self)
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
