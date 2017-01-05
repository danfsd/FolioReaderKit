//
//  FolioReaderWebView.swift
//  Pods
//
//  Created by Daniel F. Sampaio on 22/11/16.
//
//

import UIKit
import MenuItemKit

open class FolioReaderWebView: UIWebView {
    
    var isColors = false
    var isShare = false
    var isOneWord = false
    var createDiscussionAction: MenuItemAction!

    override init(frame: CGRect) {
        super.init(frame: frame)
        initialization()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialization()
    }
    
    fileprivate func initialization() {
        readerConfig.allowSharing = false
        createDiscussionAction = { [weak self] item in
            self?.createDiscussion(nil)
        }
    }
    
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        
        guard readerConfig != nil else {
            return super.canPerformAction(action, withSender: sender)
        }
        
        if isShare {
            var isDiscussion = false
            if let highlightId = selectedHighlightId {
                isDiscussion = FolioReader.sharedInstance.readerContainer.isDiscussion(highlightWith: highlightId)
            }
            
            if isDiscussion {
                
            } else {
                if action == #selector(copyText(_:))
                    || action == #selector(createAnnotation(_:)) {
                    return true
                }
            }
            return false
        } else if isColors {
            return false
        } else {
            if action == #selector(highlight(_:))
                || action == #selector(createAnnotation(_:))
                || (action == #selector(define(_:)) && isOneWord)
                || (action == #selector(play(_:)) && (book.hasAudio() || readerConfig.enableTTS))
                || (action == #selector(share(_:)) && readerConfig.allowSharing)
                || action == #selector(copyText(_:)) {
                return true
            }
            return false
        }
        
//        if isShare {
//            var isDiscussion = false
//            if let highlightId = selectedHighlightId {
//                isDiscussion = FolioReader.sharedInstance.readerContainer.isDiscussion(highlightWith: highlightId)
//            }
//            
//            if isDiscussion {
//                if action == #selector(self.colors(_:)) ||
//                    (action == #selector(self.share(_:)) && readerConfig.allowSharing) ||
//                    action == #selector(self.remove(_:)) ||
//                    action == #selector(self.copyText(_:)) ||
//                    action == #selector(self.createAnnotation(_:)) {
//                    
//                    return true
//                }
//                return false
//            } else {
//                if action == #selector(self.colors(_:)) ||
//                    (action == #selector(self.share(_:)) && readerConfig.allowSharing) ||
//                    action == #selector(self.remove(_:)) ||
//                    action == #selector(self.copyText(_:)) ||
//                    action == #selector(self.createDiscussion(_:)) ||
//                    action == #selector(self.createAnnotation(_:)) {
//                    
//                    return true
//                }
//                return false
//            }
//            return false
//            // menu for selecting highlight color
//        } else if isColors {
//            if action == #selector(self.setYellow(_:)) || action == #selector(self.setGreen(_:)) || action == #selector(self.setBlue(_:)) || action == #selector(self.setPink(_:)) || action == #selector(self.setUnderline(_:)) {
//                return true
//                
//            }
//            
//            return false
//            
//            // default menu
//        } else {
//            var isOneWord = false
//            if let result = js("getSelectedText()") , result.components(separatedBy: " ").count == 1 {
//                isOneWord = true
//            }
//            
//            if (action == #selector(self.highlight(_:)) ||
//                action == #selector(self.copyText(_:)) ||
//                action == #selector(self.createDiscussion(_:)) ||
//                action == #selector(self.createAnnotation(_:)))
//                || (action == #selector(self.define(_:)) && isOneWord)
//                || (action == #selector(self.play(_:)) && (book.hasAudio() || readerConfig.enableTTS))
//                || (action == #selector(self.share(_:)) && readerConfig.allowSharing)
//                || (action == #selector(NSObject.copy) && readerConfig.allowSharing) {
//                return true
//            }
//            return false
//        }
    }
    
    open override var canBecomeFirstResponder : Bool {
        return true
    }
    
    // MARK: - UIMenuController - Actions
    
    func share(_ sender: UIMenuController) {
        
        if isShare {
            if let textToShare = js("getHighlightContent()") {
                FolioReader.sharedInstance.readerCenter.shareHighlight(textToShare, rect: sender.menuFrame)
            }
        } else {
            if let textToShare = js("getSelectedText()") {
                FolioReader.sharedInstance.readerCenter.shareHighlight(textToShare, rect: sender.menuFrame)
            }
        }
        
        setMenuVisible(false)
    }
    
    func colors(_ sender: UIMenuController?) {
        isColors = true
        createMenu(options: false)
        setMenuVisible(true)
    }
    
    func remove(_ sender: UIMenuController?) {
        if let removedId = js("removeThisHighlight()") {
            Highlight.removeById(removedId)
            
            FolioReader.sharedInstance.readerContainer.highlightWasRemoved(removedId)
        }
        
        setMenuVisible(false)
    }
    
    func copyText(_ sender: UIMenuController?) {
        if let selectedText = js("getSelectedText()") {
            UIPasteboard.general.string = selectedText
        } else if let highlightText = js("getHighlightContent()") {
            UIPasteboard.general.string = highlightText
        }
    }
    
    func createDiscussion(_ sender: UIMenuController?) {
        if let selectedText = js("getSelectedText()") {
            // create highlight
            if let highlight = createHighlight().highlight {
                // create discussion
                FolioReader.sharedInstance.readerContainer.createDiscussion(from: highlight)
            }
        } else if let highlightId = selectedHighlightId, let selectedHighlight =  Highlight.findByHighlightId(highlightId) {
            FolioReader.sharedInstance.readerContainer.createDiscussion(from: selectedHighlight)
        }
    }
    
    func createAnnotation(_ sender: UIMenuController?) {
        var highlight: Highlight!
        
        if let jsonString = js("createAnnotation()") {
            let jsonData = jsonString.data(using: String.Encoding.utf8)
            do {
                let json = try JSONSerialization.jsonObject(with: jsonData!, options: []) as! NSArray
                let dic = json.firstObject as! [String: String]
                
                highlight = Highlight()
                highlight.content = dic["content"]!
                highlight.contentPre = dic["contentPre"]!
                highlight.contentPost = dic["contentPost"]!
                highlight.page = currentPageNumber
            } catch {
                print("Could not receive JSON")
            }
        } else if let highlightId = selectedHighlightId, let selectedHighlight =  Highlight.findByHighlightId(highlightId) {
            highlight = Highlight()
            highlight.content = selectedHighlight.content
            highlight.contentPre = selectedHighlight.contentPre
            highlight.contentPost = selectedHighlight.contentPost
            highlight.page = selectedHighlight.page
        }
        
        highlight.date = Foundation.Date()
        FolioReader.sharedInstance.readerContainer.createAnnotation(from: highlight)
    }
    
    func createHighlight() -> (highlight: Highlight?, rect: CGRect?) {
        let highlightAndReturn = js("highlightString('\(HighlightStyle.classForStyle(FolioReader.sharedInstance.currentHighlightStyle))')")
        let jsonData = highlightAndReturn?.data(using: String.Encoding.utf8)
        
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData!, options: []) as! NSArray
            let dic = json.firstObject as! [String: String]
            let rect = CGRectFromString(dic["rect"]!)
            let startOffset = dic["startOffset"]!
            let endOffset = dic["endOffset"]!
            
            // Force remove text selection
            isUserInteractionEnabled = false
            isUserInteractionEnabled = true
            
            // Persist
            let html = js("getHTML()")
            if let highlight = Highlight.matchHighlight(html, andId: dic["id"]!, startOffset: startOffset, endOffset: endOffset) {
                highlight.persist()
                
                FolioReader.sharedInstance.readerContainer.highlightWasPersisted(highlight)
                return (highlight: highlight, rect: rect)
            }
            return (highlight: nil, rect: nil)
        } catch {
            print("Could not receive JSON")
        }
        return (highlight: nil, rect: nil)
    }
    
    func highlight(_ sender: UIMenuController?) {
        if let rect = createHighlight().rect {
            createMenu(options: true)
            setMenuVisible(true, andRect: rect)
        }
    }
    
    func define(_ sender: UIMenuController?) {
        let selectedText = js("getSelectedText()")
        
        setMenuVisible(false)
        isUserInteractionEnabled = false
        isUserInteractionEnabled = true
        
        let vc = UIReferenceLibraryViewController(term: selectedText! )
        vc.view.tintColor = readerConfig.tintColor
        FolioReader.sharedInstance.readerContainer.show(vc, sender: nil)
    }
    
    func play(_ sender: UIMenuController?) {
        FolioReader.sharedInstance.readerAudioPlayer.play()
        
        // Force remove text selection
        // @NOTE: this doesn't seem to always work
        isUserInteractionEnabled = false
        isUserInteractionEnabled = true
    }
    
    
    // MARK: - Set highlight styles
    
    func setYellow(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .yellow)
    }
    
    func setGreen(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .green)
    }
    
    func setBlue(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .blue)
    }
    
    func setPink(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .pink)
    }
    
    func setUnderline(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .underline)
    }
    
    func changeHighlightStyle(_ sender: UIMenuController?, style: HighlightStyle) {
        FolioReader.sharedInstance.currentHighlightStyle = style.rawValue
        
        if let updateId = js("setHighlightStyle('\(HighlightStyle.classForStyle(style.rawValue))')") {
            Highlight.updateById(updateId, type: style)
            
            FolioReader.sharedInstance.readerContainer.highlightWasUpdated(updateId, style: style.hashValue)
        }
        colors(sender)
    }
    
    // MARK: - Create and show menu
    
    open func createMenu(options options: Bool) {
        isShare = options
        
        let colors = UIImage(readerImageNamed: "colors-marker")
        let discussion = UIImage(readerImageNamed: "discussion-marker")
        let share = UIImage(readerImageNamed: "share-marker")
        let remove = UIImage(readerImageNamed: "no-marker")
        let yellow = UIImage(readerImageNamed: "yellow-marker")
        let green = UIImage(readerImageNamed: "green-marker")
        let blue = UIImage(readerImageNamed: "blue-marker")
        let pink = UIImage(readerImageNamed: "pink-marker")
        let underline = UIImage(readerImageNamed: "underline-marker")
        
        let menuController = UIMenuController.shared
        
        let copyItem = UIMenuItem(title: readerConfig.localizedCopyMenu, action: #selector(copyText(_:)))
        let annotationItem = UIMenuItem(title: readerConfig.localizedAnnotationMenu, action: #selector(self.createAnnotation(_:)))
        let highlightItem = UIMenuItem(title: readerConfig.localizedHighlightMenu, action: #selector(highlight(_:)))
        let discussionItem = UIMenuItem(title: "D", image: discussion!, action: createDiscussionAction)
        
//        let discussionItem = UIMenuItem(title: "D", image: discussion!) { [weak self] _ in
//            self?.createHighlight()
//        }
        
        let playAudioItem = UIMenuItem(title: readerConfig.localizedPlayMenu, action: #selector(play(_:)))
        let defineItem = UIMenuItem(title: readerConfig.localizedDefineMenu, action: #selector(define(_:)))
        let colorsItem = UIMenuItem(title: "C", image: colors) { [weak self] _ in
            self?.colors(menuController)
        }
        let shareItem = UIMenuItem(title: "S", image: share) { [weak self] _ in
            self?.share(menuController)
        }
        let removeItem = UIMenuItem(title: "R", image: remove) { [weak self] _ in
            self?.remove(menuController)
        }
        let yellowItem = UIMenuItem(title: "Y", image: yellow) { [weak self] _ in
            self?.setYellow(menuController)
        }
        let greenItem = UIMenuItem(title: "G", image: green) { [weak self] _ in
            self?.setGreen(menuController)
        }
        let blueItem = UIMenuItem(title: "B", image: blue) { [weak self] _ in
            self?.setBlue(menuController)
        }
        let pinkItem = UIMenuItem(title: "P", image: pink) { [weak self] _ in
            self?.setPink(menuController)
        }
        let underlineItem = UIMenuItem(title: "U", image: underline) { [weak self] _ in
            self?.setUnderline(menuController)
        }
        
        var menuItems = [shareItem]
        
        // menu on existing highlight
        if isShare {
            // [Copiar, Anotação, Cores, Remover]
            menuItems = [copyItem, annotationItem,  colorsItem, removeItem]
            if readerConfig.allowSharing {
                menuItems.append(shareItem)
            }
        } else if isColors {
            // menu for selecting highlight color
            menuItems = [yellowItem, greenItem, blueItem, pinkItem, underlineItem]
        } else {
            // default menu [Copiar, Destaque, Anotação, Criar discussão (desabilitado)]
            menuItems = [copyItem, highlightItem, annotationItem, shareItem]
            
//            if book.hasAudio() || readerConfig.enableTTS {
//                menuItems.insert(playAudioItem, at: 0)
//            }
            
            if !readerConfig.allowSharing {
                menuItems.removeLast()
            }
        }
        
        menuController.menuItems = menuItems
    }
    
    open func setMenuVisible(_ menuVisible: Bool, animated: Bool = true, andRect rect: CGRect = CGRect.zero) {
        if !menuVisible && isShare || !menuVisible && isColors {
            isColors = false
            isShare = false
        }
        
        if menuVisible  {
            if !rect.equalTo(CGRect.zero) {
                UIMenuController.shared.setTargetRect(rect, in: self)
            }
        }
        
        UIMenuController.shared.setMenuVisible(menuVisible, animated: animated)
    }
    
    @discardableResult func js(_ script: String) -> String? {
        let callback = self.stringByEvaluatingJavaScript(from: script)
        if callback!.isEmpty { return nil }
        return callback
    }
    
    // MARK: WebView direction config
    
    func setupScrollDirection() {
        switch readerConfig.scrollDirection {
        case .vertical, .horizontalWithVerticalContent:
            scrollView.isPagingEnabled = false
            paginationMode = .unpaginated
            scrollView.bounces = true
            break
        case .horizontal:
            scrollView.isPagingEnabled = true
            paginationMode = .leftToRight
            paginationBreakingMode = .page
            scrollView.bounces = false
            break
        }
    }
}
