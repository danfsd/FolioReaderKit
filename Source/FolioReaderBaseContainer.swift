//
//  FolioReaderBaseContainer.swift
//  FolioReaderKit
//
//  Created by Daniel F. Sampaio on 23/06/16.
//  Copyright © 2016 FolioReader. All rights reserved.
//

import UIKit
import FontBlaster

var readerConfig: FolioReaderConfig!
var epubPath: String?
var book: FRBook!

public class FolioReaderBaseContainer: UIViewController {
    public var centerNavigationController: UINavigationController!
    public var centerViewController: FolioReaderCenter!
    var audioPlayer: FolioReaderAudioPlayer?
    
    /**
     Indicates whether the `audioPlayer` will be setup.
     */
    var shouldSetupAudioPlayer = true
    
    /**
     Indicates whether the `statusBar` will be visible.
     */
    var shouldHideStatusBar = true
    
    private var errorOnLoad = false {
        didSet {
            // TODO: dismiss view controller animated.
            dismissViewControllerAnimated(true, completion: nil)
        }
    }
    private var shouldRemoveEpub = true
    
    // MARK: - Init
    
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
    
    // MARK: - View life cicle
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupCenterViewController()
        setupNavigationController()
        setupNavigationBar()
        loadEbook()
    }
    
    override public func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        showShadowForCenterViewController(true)
    }
    
    // MARK: - Book
    
    /**
     Loads the `FREbook` from an **epub file**. If it cannot be found, an the view controller will be dismissed.
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
                    book = FREpubParser().readEpub(epubPath: path)
                } else {
                    book = FREpubParser().readEpub(epubPath: path, removeEpub: self.shouldRemoveEpub)
                }
            } else {
                print("Epub file does not exist.")
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
        self.centerViewController.reloadData()
        
        if shouldSetupAudioPlayer {
            setupAudioPlayer()
        }
        
        FolioReader.sharedInstance.isReaderReady = true
    }
    
    // MARK: - Setup
    
    /**
     Initializes a `FolioReaderCenter`, sets itself as the container, and sets it on the `FolioReader` singleton.
     */
    public func setupCenterViewController() {
        centerViewController = FolioReaderCenter()
        centerViewController.folioReaderContainer = self
        FolioReader.sharedInstance.readerCenter = centerViewController
    }
    
    /**
     Initializes the `centerNavigationController` with `centerViewController` as the root view controller, adds it to the view hierarchy,
     and configures the navigation bar.
     
     - precondition: `centerViewController` has already been set.
     */
    public func setupNavigationController() {
        // TODO: maybe use customNavigationController
        centerNavigationController = UINavigationController(rootViewController: centerViewController)
        centerNavigationController.setNavigationBarHidden(readerConfig.shouldHideNavigationOnTap, animated: false)
        
        view.addSubview(centerNavigationController.view)
        addChildViewController(centerNavigationController)
        centerNavigationController.didMoveToParentViewController(self)
    }
    
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
    
    private func setupAudioPlayer() {
        // TODO: verify if audioplayer has SMILS
        audioPlayer = FolioReaderAudioPlayer()
        
        FolioReader.sharedInstance.readerAudioPlayer = audioPlayer
    }
    
    func showShadowForCenterViewController(shouldShowShadow: Bool) {
        if (shouldShowShadow) {
            centerNavigationController.view.layer.shadowOpacity = 0.2
            centerNavigationController.view.layer.shadowRadius = 6
            centerNavigationController.view.layer.shadowPath = UIBezierPath(rect: centerNavigationController.view.bounds).CGPath
            centerNavigationController.view.clipsToBounds = false
        } else {
            centerNavigationController.view.layer.shadowOpacity = 0
            centerNavigationController.view.layer.shadowRadius = 0
        }
    }
    
    func hideNavigationBar() {
        print("[INFO] - hiding navigation bar")
        guard readerConfig.shouldHideNavigationOnTap else { return }
        
        shouldHideStatusBar = true
        UIView.animateWithDuration(0.25, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        })
        centerNavigationController.setNavigationBarHidden(shouldHideStatusBar, animated: true)
    }
    
    func showNavigationBar() {
        print("[INFO] - showing navigation bar")
        setupNavigationBar()
        
        shouldHideStatusBar = false
        UIView.animateWithDuration(0.25, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        })
        centerNavigationController.setNavigationBarHidden(shouldHideStatusBar, animated: true)
    }
    
    func toggleNavigationBar() {
        print("[INFO] - toggling navigation bar")
        guard readerConfig.shouldHideNavigationOnTap else { return }
        
        let shouldHide = !centerNavigationController.navigationBarHidden
        if !shouldHide { setupNavigationBar() }
        
        print("[INFO] - left bar: \(centerNavigationController.navigationItem.leftBarButtonItem)")
        
        shouldHideStatusBar = shouldHide
        UIView.animateWithDuration(0.25, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        })
        centerNavigationController.setNavigationBarHidden(shouldHideStatusBar, animated: true)
    }
    
    func addGestureRecognizer(gesture: UIGestureRecognizer) {
        centerNavigationController.view.addGestureRecognizer(gesture)
    }
    

}