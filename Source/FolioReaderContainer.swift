//
//  FolioReaderContainer.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 15/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import FontBlaster

//var readerConfig: FolioReaderConfig!
//var epubPath: String?
//var book: FRBook!

class FolioReaderContainer: UIViewController {
    var centerNavigationController: UINavigationController!
    var centerViewController: FolioReaderCenter!
    var audioPlayer: FolioReaderAudioPlayer!
    var shouldHideStatusBar = true
    private var errorOnLoad = false
    private var shouldRemoveEpub = true
    
    // MARK: - Init
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(config configOrNil: FolioReaderConfig!, epubPath epubPathOrNil: String? = nil, removeEpub: Bool) {
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
            kCurrentTOCMenu: 0,
            kCurrentMediaOverlayStyle: MediaOverlayStyle.Default.rawValue
        ])
    }
    
    // MARK: - View life cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centerViewController = FolioReaderCenter()
        FolioReader.sharedInstance.readerCenter = centerViewController
        
        centerNavigationController = UINavigationController(rootViewController: centerViewController)
        centerNavigationController.setNavigationBarHidden(readerConfig.shouldHideNavigationOnTap, animated: false)
        view.addSubview(centerNavigationController.view)
        addChildViewController(centerNavigationController)
        centerNavigationController.didMoveToParentViewController(self)

        // Read async book
        if (epubPath != nil) {
            let priority = DISPATCH_QUEUE_PRIORITY_HIGH
            dispatch_async(dispatch_get_global_queue(priority, 0), { () -> Void in
                
                var isDir: ObjCBool = false
                let fileManager = NSFileManager.defaultManager()
                
                if fileManager.fileExistsAtPath(epubPath!, isDirectory:&isDir) {
                    if isDir {
                        book = FREpubParser().readEpub(filePath: epubPath!)
                    } else {
                        book = FREpubParser().readEpub(epubPath: epubPath!, removeEpub: self.shouldRemoveEpub)
                    }
                }
                else {
                    print("Epub file does not exist.")
                    self.errorOnLoad = true
                }
                
                FolioReader.sharedInstance.isReaderOpen = true
                
                if !self.errorOnLoad {
                    // Reload data
                    dispatch_async(dispatch_get_main_queue(), {
                        
                        // Add audio player if needed
                        if book.hasAudio() || readerConfig.enableTTS {
                            self.addAudioPlayer()
                        }
                        
                        self.centerViewController.reloadData()
                        
                        FolioReader.sharedInstance.isReaderReady = true
                    })
                }
            })
        } else {
            print("Epub path is nil.")
            errorOnLoad = true
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if errorOnLoad {
            dismiss()
        }
    }
    
    /**
     Initialize the media player
     */
    func addAudioPlayer(){
        audioPlayer = FolioReaderAudioPlayer()
        FolioReader.sharedInstance.readerAudioPlayer = audioPlayer;
    }
    
    // MARK: - Status Bar
    
    override func prefersStatusBarHidden() -> Bool {
        return readerConfig.shouldHideNavigationOnTap == false ? false : shouldHideStatusBar
    }
    
    override func preferredStatusBarUpdateAnimation() -> UIStatusBarAnimation {
        return UIStatusBarAnimation.Slide
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return isNight(.LightContent, .Default)
    }
}
