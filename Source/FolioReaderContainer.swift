//
//  FolioReaderContainer.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 15/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

enum SlideOutState {
    case BothCollapsed
    case LeftPanelExpanded
    case Expanding
    
    init () {
        self = .BothCollapsed
    }
}

protocol FolioReaderContainerDelegate: class {
    /**
     Notifies that the menu was expanded.
     */
    func container(didExpandLeftPanel sidePanel: FolioReaderSidePanel)
    
    /**
     Notifies that the menu was closed.
     */
    func container(didCollapseLeftPanel sidePanel: FolioReaderSidePanel)
    
    /**
     Notifies when the user selected some item on menu.
     */
    func container(sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: NSIndexPath, withTocReference reference: FRTocReference)
}

class FolioReaderContainer: FolioReaderBaseContainer, FolioReaderSidePanelDelegate {
    //weak var delegate: FolioReaderContainerDelegate!
    var leftViewController: FolioReaderSidePanel!
    var centerPanelExpandedOffset: CGFloat = 70
    var currentState = SlideOutState()
    
    // MARK: - Initializer
    
    override required public init(config configOrNil: FolioReaderConfig!, epubPath epubPathOrNil: String? = nil, removeEpub: Bool) {
        super.init(config: configOrNil, epubPath: epubPathOrNil, removeEpub: removeEpub)
        
        shouldSetupAudioPlayer = true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - View life cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add gestures
        setupTapGestureRecognizer()
        setupPanGestureRecognizer()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - Book
    
    override func ebookDidLoad() {
        print("[INFO] - FolioReaderContainer::ebookDidLoad()")
        super.ebookDidLoad()
        
        self.addLeftPanelViewController()
        if FolioReader.defaults.valueForKey(kBookId) == nil {
            self.toggleLeftPanel()
        }
    }
    
    // MARK: - Setup
    
    override func setupCenterViewController() {
        super.setupCenterViewController()
        
        centerViewController.delegate = self
    }
    
    func setupTapGestureRecognizer() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(FolioReaderContainer.handleTapGesture(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        addGestureRecognizer(tapGestureRecognizer)
    }
    
    func setupPanGestureRecognizer() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(FolioReaderContainer.handlePanGesture(_:)))
        addGestureRecognizer(panGestureRecognizer)
    }
    
    func configureNavBarButtons() {
        
        // Navbar buttons
        let shareIcon = UIImage(readerImageNamed: "btn-navbar-share")!.imageTintColor(readerConfig.tintColor).imageWithRenderingMode(.AlwaysOriginal)
        let audioIcon = UIImage(readerImageNamed: "man-speech-icon")!.imageTintColor(readerConfig.tintColor).imageWithRenderingMode(.AlwaysOriginal)
        let menuIcon = UIImage(readerImageNamed: "btn-navbar-menu")!.imageTintColor(readerConfig.tintColor).imageWithRenderingMode(.AlwaysOriginal)
        
        centerViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(image: menuIcon, style: UIBarButtonItemStyle.Plain, target: self, action:#selector(FolioReaderContainer.toggleMenu(_:)))
        
        var rightBarIcons = [UIBarButtonItem]()
        
        if readerConfig.allowSharing {
            rightBarIcons.append(UIBarButtonItem(image: shareIcon, style: UIBarButtonItemStyle.Plain, target: centerViewController, action:#selector(FolioReaderCenter.shareChapter(_:))))
        }
        
        if (book.hasAudio() || readerConfig.enableTTS) && shouldSetupAudioPlayer {
            rightBarIcons.append(UIBarButtonItem(image: audioIcon, style: UIBarButtonItemStyle.Plain, target: centerViewController, action:#selector(FolioReaderCenter.togglePlay(_:))))
        }
        
        centerViewController.navigationItem.rightBarButtonItems = rightBarIcons
    }
    
    // MARK: CenterViewController delegate methods
    
    func toggleMenu(notification: NSNotification) {
        toggleLeftPanel()
    }
    
    func toggleLeftPanel() {
        let notAlreadyExpanded = (currentState != .LeftPanelExpanded)
        
        if notAlreadyExpanded {
            addLeftPanelViewController()
        }
        
        animateLeftPanel(shouldExpand: notAlreadyExpanded)
    }
    
    func collapseSidePanels() {
        switch (currentState) {
        case .LeftPanelExpanded:
            toggleLeftPanel()
        default:
            break
        }
    }
    
    func addLeftPanelViewController() {
        if (leftViewController == nil) {
            leftViewController = FolioReaderSidePanel()
            leftViewController.delegate = self
            addChildSidePanelController(leftViewController!)
            
            FolioReader.sharedInstance.readerSidePanel = leftViewController
        }
    }
    
    func addChildSidePanelController(sidePanelController: FolioReaderSidePanel) {
        view.insertSubview(sidePanelController.view, atIndex: 0)
        addChildViewController(sidePanelController)
        sidePanelController.didMoveToParentViewController(self)
    }
    
    func animateLeftPanel(shouldExpand shouldExpand: Bool) {
        if (shouldExpand) {
            
            if let width = pageWidth {
                if isPad {
                    centerPanelExpandedOffset = width-400
                } else {
                    // Always get the device width
                    let w = UIInterfaceOrientationIsPortrait(UIApplication.sharedApplication().statusBarOrientation) ? UIScreen.mainScreen().bounds.size.width : UIScreen.mainScreen().bounds.size.height
                    
                    centerPanelExpandedOffset = width-(w-70)
                }
            }
            
            currentState = .LeftPanelExpanded
//            delegate.container(didExpandLeftPanel: leftViewController)
            centerViewController.disableUserInteraction()
            animateCenterPanelXPosition(targetPosition: CGRectGetWidth(centerNavigationController.view.frame) - centerPanelExpandedOffset)
            
            // Reload to update current reading chapter
            leftViewController.tableView.reloadData()
        } else {
            animateCenterPanelXPosition(targetPosition: 0) { finished in
//                self.delegate.container(didCollapseLeftPanel: self.leftViewController)
                self.centerViewController.enableUserInteraction()
                self.currentState = .BothCollapsed
            }
        }
    }
    
    func animateCenterPanelXPosition(targetPosition targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .CurveEaseInOut, animations: {
            self.centerNavigationController.view.frame.origin.x = targetPosition
            }, completion: completion)
    }
    
    // MARK: Gesture recognizer
    
    func handleTapGesture(recognizer: UITapGestureRecognizer) {
        if currentState == .LeftPanelExpanded {
            toggleLeftPanel()
        }
    }
    
    func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        let gestureIsDraggingFromLeftToRight = (recognizer.velocityInView(view).x > 0)
        
        switch(recognizer.state) {
        case .Began:
            if currentState == .BothCollapsed && gestureIsDraggingFromLeftToRight {
                currentState = .Expanding
            }
        case .Changed:
            if currentState == .LeftPanelExpanded || currentState == .Expanding && recognizer.view!.frame.origin.x >= 0 {
                recognizer.view!.center.x = recognizer.view!.center.x + recognizer.translationInView(view).x
                recognizer.setTranslation(CGPointZero, inView: view)
            }
        case .Ended:
            if leftViewController != nil {
                let gap = 20 as CGFloat
                let xPos = recognizer.view!.frame.origin.x
                let canFinishAnimation = gestureIsDraggingFromLeftToRight && xPos > gap ? true : false
                animateLeftPanel(shouldExpand: canFinishAnimation)
            }
        default:
            break
        }
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
    
    // MARK: - Side Panel delegate
    
    func sidePanel(sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: NSIndexPath, withTocReference reference: FRTocReference) {
        collapseSidePanels()
//        delegate.container(sidePanel, didSelectRowAtIndexPath: indexPath, withTocReference: reference)
        centerViewController.updateCurrentPage(fromIndexPath: indexPath, withTocReference: reference)
    }
}

extension FolioReaderContainer: FolioReaderCenterDelegate {
    func center(didReloadData center: FolioReaderCenter) {
        print("[INFO] - did reload data")
        self.configureNavBarButtons()
    }
}
