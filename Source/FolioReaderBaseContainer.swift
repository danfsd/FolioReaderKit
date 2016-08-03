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

public class FolioReaderBaseContainer: UIViewController {
    
    // MARK: - Variables
    
    public var centerNavigationController: UINavigationController!
    // TODO: make it public
    var centerViewController: FolioReaderCenter!
    var audioPlayer: FolioReaderAudioPlayer?
    
    /**
     Indicates whether the `statusBar` will be visible.
     */
    var shouldHideStatusBar = true
    
    /**
     Indicates wheter the default navigation bar will be setup
    */
    var shouldUseDefaultNavigationBar = true
    
    /**
     Indicates whether the `audioPlayer` will be setup.
     */
    var shouldSetupAudioPlayer = true
    
    /**
     Indicates whether the epub will be removed from the disk after being parsed
    */
    private var shouldRemoveEpub = false
    
    private var errorOnLoad = false {
        didSet {
            if errorOnLoad {
                print("[INFO] - Error loading container")
                // TODO: dismissViewControllerAnimated
            }
        }
    }
    
    // MARK: - Initializers
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    required public init(config configOrNil: FolioReaderConfig!, epubPath epubPathOrNil: String? = nil, removeEpub: Bool) {
        readerConfig = configOrNil
        epubPath = epubPathOrNil
        shouldRemoveEpub = removeEpub
        super.init(nibName: nil, bundle: NSBundle.frameworkBundle())
        
        // Init with empty book
        book = FRBook()
        
        // Register custom fonts
        FontBlaster.blast(NSBundle.frameworkBundle())
        
        // Register initial defaults
        FolioReader.defaults.registerDefaults([
            kCurrentFontFamily: 0,
            kNightMode: false,
            kCurrentFontSize: 2,
            kCurrentAudioRate: 1,
            kCurrentHighlightStyle: 0,
            kCurrentMediaOverlayStyle: MediaOverlayStyle.Default.rawValue
            ])
    }
    
    // MARK: - View life cycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: setup center view controller
        // TODO: setup navigation controller
        if shouldUseDefaultNavigationBar {
            // TODO: setup default navigation bar
        }
        // TODO: load ebook
    }
    
    /**
     Reads the epub from `epubPath` and parses it to a `FRBook` instance.
    */
    private func loadEbook() {
        guard let path = epubPath else {
            print("Epub path is nil.")
            errorOnLoad = true
            return
        }
        
        let priority = DISPATCH_QUEUE_PRIORITY_HIGH
        dispatch_async(dispatch_get_global_queue(priority, 0), {
            Void in
            var isDir: ObjCBool = false
            let fileManager = NSFileManager.defaultManager()
            
            if fileManager.fileExistsAtPath(path, isDirectory: &isDir) {
                if isDir {
                    print("Epub loaded from dir")
                    book = FREpubParser().readEpub(epubPath: path)
                } else {
                    print("Epub lodaded from file [shouldRemove=\(self.shouldRemoveEpub)]")
                    book = FREpubParser().readEpub(epubPath: path, removeEpub: self.shouldRemoveEpub)
                }
            } else {
                print("Epub file does not exist.")
                self.errorOnLoad = true
            }
            
            FolioReader.sharedInstance.isReaderOpen = true
            
            dispatch_async(dispatch_get_main_queue(), self.ebookDidLoad)
        })
    }
    
    /**
     Called when `loadEbook` function finishes getting the file from the disk.
     
     - precondition: `book` should be set.
     */
    public func ebookDidLoad() {
        print("[INFO] - FolioReaderBaseContainer::ebookDidLoad()")
        // TODO: reload centerViewController
        
        if shouldSetupAudioPlayer {
            // TODO: setup audioPlayer
        }
        
        FolioReader.sharedInstance.isReaderReady = true
    }
    
    // MARK: - Setup
    
    /**
     Initializes a `FolioReaderCenter`, sets itself as the container, and sets it on the `FolioReader` singleton.
     */
    func setupReaderCenter() {
        centerViewController = FolioReaderCenter()
        // TODO: self itself as center's container
        FolioReader.sharedInstance.readerCenter = centerViewController
    }
    
    /**
     Initializes the `centerNavigationController` with `centerViewController` as the root view controller, adds it to the view hierarchy,
     and configures the navigation bar.
     
     - precondition: `centerViewController` has already been set.
     */
    func setupReaderNavigationController() {
        centerNavigationController = UINavigationController(rootViewController: centerViewController)
        centerNavigationController.setNavigationBarHidden(readerConfig.shouldHideNavigationOnTap, animated: false)
        
        view.addSubview(centerNavigationController.view)
        addChildViewController(centerNavigationController)
        centerNavigationController.didMoveToParentViewController(self)
    }
    
    /**
     Setup FolioReader's default navigation bar.
     
     - precondition: `shouldUseDefaultNavigationBar` must be true.
    */
    func setupNavigationBar() {
        print("[INFO] - setupping navigation bar")
        automaticallyAdjustsScrollViewInsets = false
        extendedLayoutIncludesOpaqueBars = true
        
        let navBackground = isNight(readerConfig.nightModeBackground, UIColor.whiteColor())
        let tintColor = readerConfig.tintColor
        let navText = isNight(UIColor.whiteColor(), UIColor.blackColor())
        let font = UIFont(name: "Avenir-Light", size: 10)!
        setTranslucentNavigation(color: navBackground, tintColor: tintColor, titleColor: navText, andFont: font)
    }
    
    /**
     Setup FolioReader's audio player.
     
     - precondition: `shouldSetupAudioPlayer` must be true.
    */
    func setupAudioPlayer() {
        // TODO: verify if audioplayer has SMILS
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
        UIView.animateWithDuration(0.25) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
        centerNavigationController.setNavigationBarHidden(shouldHideStatusBar, animated: true)
    }
    
    /**
     Called to show the `centerNavigationController` navigation bar.
     */
    func showNavigationBar() {
        setupNavigationBar()
        
        shouldHideStatusBar = false
        UIView.animateWithDuration(0.25) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
        centerNavigationController.setNavigationBarHidden(shouldHideStatusBar, animated: true)
    }
    
    /**
     Called to toggle the `centerNavigationController` navigation bar.
     */
    func toggleNavigationBar() {
        guard readerConfig.shouldHideNavigationOnTap else { return }
        
        let shouldHide = !centerNavigationController.navigationBarHidden
        if !shouldHide { setupNavigationBar() }
        shouldHideStatusBar = shouldHide
        UIView.animateWithDuration(0.25) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
        centerNavigationController.setNavigationBarHidden(shouldHideStatusBar, animated: true)
    }
}
