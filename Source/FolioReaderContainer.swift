//
//  FolioReaderContainer.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 15/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

public class FolioReaderContainer: FolioReaderBaseContainer {
    
    // MARK: - Init
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    required public init(config configOrNil: FolioReaderConfig!, navigationConfig navigationConfigOrNil: FolioReaderNavigationConfig!, epubPath epubPathOrNil: String? = nil, removeEpub: Bool) {
        super.init(config: configOrNil, navigationConfig: navigationConfigOrNil,epubPath: epubPathOrNil, removeEpub: removeEpub)
        shouldSetupAudioPlayer = true
    }
    
    // MARK: - View life cicle
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override public func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - Status Bar
    
    override public func prefersStatusBarHidden() -> Bool {
        return readerConfig.shouldHideNavigationOnTap == false ? false : shouldHideStatusBar
    }
    
    override public func preferredStatusBarUpdateAnimation() -> UIStatusBarAnimation {
        return UIStatusBarAnimation.Slide
    }
    
    override public func preferredStatusBarStyle() -> UIStatusBarStyle {
        return isNight(.LightContent, .Default)
    }
}
