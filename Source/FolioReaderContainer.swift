//
//  FolioReaderContainer.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 15/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

open class FolioReaderContainer: FolioReaderBaseContainer {
    
    // MARK: - Init
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    required public init(config configOrNil: FolioReaderConfig!, navigationConfig navigationConfigOrNil: FolioReaderNavigationConfig!, epubPath epubPathOrNil: String? = nil, removeEpub: Bool) {
        super.init(config: configOrNil, navigationConfig: navigationConfigOrNil,epubPath: epubPathOrNil, removeEpub: removeEpub)
        shouldSetupAudioPlayer = true
    }
    
    open override func setupNavigationItens() { super.setupNavigationItens() }
    
    open override func setupBackMenuView() { super.setupBackMenuView() }
    
    // MARK: - View life cicle
    
    override open func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - Status Bar
    
    override open var prefersStatusBarHidden : Bool {
        return readerConfig.shouldHideNavigationOnTap == false ? false : shouldHideStatusBar
    }
    
    override open var preferredStatusBarUpdateAnimation : UIStatusBarAnimation {
        return UIStatusBarAnimation.slide
    }
    
    override open var preferredStatusBarStyle : UIStatusBarStyle {
        return isNight(.lightContent, .default)
    }
}
