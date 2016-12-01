//
//  FolioReaderBaseContainer.swift
//  Pods
//
//  Created by Daniel F. Sampaio on 03/08/16.
//
//

import UIKit
import FontBlaster

var readerConfig: FolioReaderConfig!
var epubPath: String?
var book: FRBook!

open class FolioReaderBaseContainer: UIViewController {
    
    // MARK: - Variables
    
    open var centerNavigationController: UINavigationController!
    open var controlStates: (fontSize: Int, fontFamily: Int, textAlignment: Int)!
    open var centerViewController: FolioReaderCenter!
    open var scrollDirection: FolioReaderScrollDirection!
    var audioPlayer: FolioReaderAudioPlayer?
    
    /**
     Indicates whether the `statusBar` will be visible.
     */
    var shouldHideStatusBar = true
    
    /**
     Indicates wheter the default navigation bar will be setup
    */
    open var shouldUseDefaultNavigationBar = true {
        didSet {
//            readerConfig.shouldHideNavigation = !shouldUseDefaultNavigationBar
        }
    }
    
    /**
     Indicates whether the `audioPlayer` will be setup.
     */
    open var shouldSetupAudioPlayer = true
    
    /**
     Indicates whether the epub will be removed from the disk after being parsed
    */
    fileprivate var shouldRemoveEpub = false
    
    fileprivate var errorOnLoad = false {
        didSet {
            if errorOnLoad {
                print("[INFO] - Error loading container")
                closeReader()
            }
        }
    }
    
    // MARK: - Initializers
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    required public init(config configOrNil: FolioReaderConfig!, navigationConfig navigationConfigOrNil: FolioReaderNavigationConfig!, epubPath epubPathOrNil: String? = nil, removeEpub: Bool) {
//        print("BaseContainer.\(#function)")
        readerConfig = configOrNil
        navigationConfig = navigationConfigOrNil
        epubPath = epubPathOrNil
        shouldRemoveEpub = removeEpub
        super.init(nibName: nil, bundle: Bundle.frameworkBundle())
        
        // Init with empty book
        book = FRBook()
        
        // Register custom fonts
        FontBlaster.blast(bundle: Bundle.frameworkBundle())
        
        // Register initial defaults
        FolioReader.defaults.register(defaults: [
            kCurrentFontFamily: 0,
            kNightMode: false,
            kCurrentTextAlignment: 0,
            kCurrentFontSize: 2,
            kCurrentAudioRate: 1,
            kCurrentHighlightStyle: 0,
            kCurrentMediaOverlayStyle: MediaOverlayStyle.default.rawValue
            ])
    }
    
    // MARK: - View life cycle
    
    open override func viewDidLoad() {
//        print("BaseContainer.\(#function)")
        super.viewDidLoad()
        
        setupReaderCenter()
        setupReaderNavigationController()
        if shouldUseDefaultNavigationBar {
            setupNavigationBar()
        }
        loadEbook()
    }
    
    open func closeReader(_ shouldDismiss: Bool = true) {
        FolioReader.close()
        if shouldDismiss {
            dismiss()
        } else {
            pop()
        }
    }
    
    /**
     Reads the epub from `epubPath` and parses it to a `FRBook` instance.
    */
    fileprivate func loadEbook() {
//        print("BaseContainer.\(#function)")
        guard let path = epubPath else {
            print("Epub path is nil.")
            errorOnLoad = true
            return
        }
        
        self.controlStates = (
            fontSize: FolioReader.sharedInstance.currentFontSize,
            fontFamily: FolioReader.sharedInstance.currentFontName,
            textAlignment: FolioReader.sharedInstance.currentTextAlignement
        )
        
        let priority = DispatchQueue.GlobalQueuePriority.high
        DispatchQueue.global(priority: priority).async(execute: {
            Void in
            var isDir: ObjCBool = false
            let fileManager = FileManager.default
            
            if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
                if isDir.boolValue {
//                    print("Epub loaded from dir")
                    book = FREpubParser().readEpub(epubPath: path)
                } else {
//                    print("Epub lodaded from file [shouldRemove=\(self.shouldRemoveEpub)]")
                    book = FREpubParser().readEpub(epubPath: path, removeEpub: self.shouldRemoveEpub)
                }
            } else {
                print("Epub file does not exist.")
                self.errorOnLoad = true
            }
            
            FolioReader.sharedInstance.isReaderOpen = true
            
            DispatchQueue.main.async(execute: self.ebookDidLoad)
        })
    }
    
    
    
    /**
     Called when `loadEbook` function finishes getting the file from the disk.
     
     - precondition: `book` should be set.
     */
    open func ebookDidLoad() {
//        print("BaseContainer.\(#function)")
        centerViewController.reloadData()
        
        if shouldSetupAudioPlayer {
            setupAudioPlayer()
        }
        
        FolioReader.sharedInstance.isReaderReady = true
    }
    
    // MARK: - Setup
    
    /**
     Initializes a `FolioReaderCenter`, sets itself as the container, and sets it on the `FolioReader` singleton.
     */
    open func setupReaderCenter() {
        centerViewController = FolioReaderCenter()
        FolioReader.sharedInstance.readerCenter = centerViewController
    }
    
    /**
     Initializes the `centerNavigationController` with `centerViewController` as the root view controller, adds it to the view hierarchy,
     and configures the navigation bar.
     
     - precondition: `centerViewController` has already been set.
     */
    open func setupReaderNavigationController() {
        centerNavigationController = FolioReaderNavigationController(rootViewController: centerViewController)
        centerNavigationController.setNavigationBarHidden(readerConfig.shouldHideNavigationOnTap, animated: false)
        
        view.addSubview(centerNavigationController.view)
        addChildViewController(centerNavigationController)
        centerNavigationController.didMove(toParentViewController: self)
    }
    
    /**
     Setup FolioReader's default navigation bar.
     
     - precondition: `shouldUseDefaultNavigationBar` must be true.
    */
    open func setupNavigationBar() {
        print("[INFO] - setupping navigation bar")
        automaticallyAdjustsScrollViewInsets = false
        extendedLayoutIncludesOpaqueBars = true
        
        let navBackground = isNight(readerConfig.nightModeBackground, UIColor.white)
        let tintColor = readerConfig.tintColor
        let navText = isNight(UIColor.white, UIColor.black)
        let font = UIFont(name: "Avenir-Light", size: 10)!
        setTranslucentNavigation(color: navBackground, tintColor: tintColor, titleColor: navText, andFont: font)
        
        // TODO: chamar função do próprio leitor para configurar leftBarButtons, rightBarButtons, titleView e sobrescrever no TabletReaderContainer
    }
    
    /**
     Setup FolioReader's audio player.
     
     - precondition: `shouldSetupAudioPlayer` must be true.
    */
    func setupAudioPlayer() {
        audioPlayer = FolioReaderAudioPlayer()
        FolioReader.sharedInstance.readerAudioPlayer = audioPlayer
    }
    
    // MARK: Status bar and Navigation bar
    
    /**
     Called to hide the `centerNavigationController` navigation bar.
    */
    func hideNavigationBar() {
        guard !readerConfig.shouldHideNavigationOnTap else { return }
        
        shouldHideStatusBar = true
        UIView.animate(withDuration: 0.25, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        }) 
        centerNavigationController.setNavigationBarHidden(shouldHideStatusBar, animated: true)
    }
    
    /**
     Called to show the `centerNavigationController` navigation bar.
     */
    func showNavigationBar() {
        setupNavigationBar()
        
        shouldHideStatusBar = false
        UIView.animate(withDuration: 0.25, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        }) 
        centerNavigationController.setNavigationBarHidden(shouldHideStatusBar, animated: true)
    }
    
    /**
     Called to toggle the `centerNavigationController` navigation bar.
     */
    open func toggleNavigationBar() {
        guard readerConfig.shouldHideNavigationOnTap else { return }
        
        let shouldHide = !centerNavigationController.isNavigationBarHidden
        if !shouldHide { setupNavigationBar() }
        shouldHideStatusBar = shouldHide
        UIView.animate(withDuration: 0.25, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        }) 
        centerNavigationController.setNavigationBarHidden(shouldHideStatusBar, animated: true)
    }
    
    /**
     Called when the chapter changes.
    */
    open func chapterDidChanged(_ chapter: String) {}
    
    /**
     Called when the page is turned.
    */
    open func pageDidChanged(_ centerState: ReaderState, pageState: ReaderState) {}
    
    /**
     Called when the chapter page is turned.
     */
    open func webviewPageDidChanged(_ pageState: ReaderState) {}
    
    /**
     Called when the reading time is updated
    */
    open func readingTimeDidChanged(_ readingTime: Int) {}
    
    // MARK: - Highlight callbacks
    /**
     Called when a highlight is persisted.
    */
    open func highlightWasPersisted(_ highlight: Highlight) {}
    
    /**
     Called when a highlight is updated.
     */
    open func highlightWasUpdated(_ highlightId: String, style: Int) {}
    
    /**
     Called when a highlight is removed.
     */
    open func highlightWasRemoved(_ highlightId: String) {}
    
    /**
     Called to create a discussion from a highlight
    */
    open func createDiscussion(from highlight: Highlight) {}
    
    /**
     Verifies if the highlight with the given Id is a discussion on the app namespace
    */
    open func isDiscussion(highlightWith id: String) -> Bool { return false }
    
    open func updateReadInfos(totalPages: Int, actualPage: Int, chapter: Int){}
      
    open func updateChapterPosition(chapter: Int, position: Float){}
    
    open func getChapterPosition(chapter: Int) -> Float{ return 0.0}
    
}
