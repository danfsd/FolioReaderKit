//
//  FolioReaderConfig.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

// MARK: - FolioReaderScrollDirection

/**
 Defines the Reader scrolling direction
 */
public enum FolioReaderScrollDirection: Int {
    
    /// Section and content scroll on vertical
    case vertical
    
    /// Section and content scroll on horizontal
    case horizontal
    
    /// Sections scroll horizontal and content scroll on vertical
    case horizontalWithVerticalContent
    
    /**
     The current scroll direction
     
     - returns: Returns `UICollectionViewScrollDirection`
     */
    func collectionViewScrollDirection() -> UICollectionViewScrollDirection {
        switch self {
        case .vertical:
            return .vertical
        case .horizontal, .horizontalWithVerticalContent:
            return .horizontal
        }
    }
}


public enum FolioReaderSkipPageMode: Int {
    case hybrid
    case page
    case chapter
}

public enum FolioReaderFontName: Int {
    case andada
    case lato
    case lora
    case raleway
    
    /**
     The font name that will be used
     
     - returns: Returns `String`
    */
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
    case sizeOne
    case sizeTwo
    case sizeThree
    case sizeFour
    case sizeFive
    
    /**
     The html font size class
     
     - returns: Returns `String`
    */
    public func fontSize() -> String {
        switch self {
        case .sizeOne: return "textSizeOne"
        case .sizeTwo: return "textSizeTwo"
        case .sizeThree: return "textSizeThree"
        case .sizeFour: return "textSizeFour"
        case .sizeFive: return "textSizeFive"
        }
    }
    
    /**
     The slider threshold to trigger the size class
     
     - returns: Returns `Float`
    */
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
    case left
    case right
    case center
    case justify
    
    /**
     The CSS value for the `text-align` property
     
     - returns: Returns `String`
    */
    public func textAlignment() -> String {
        switch self {
        case .left: return "left"
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

open class FolioReaderConfig: NSObject {
    
    // Colors
    open var tintColor = UIColor(rgba: "#6ACC50")
    open var menuBackgroundColor = UIColor.white
    open var menuSeparatorColor = UIColor(rgba: "#D7D7D7")
    open var menuTextColor = UIColor(rgba: "#767676")
    open var nightModeBackground = UIColor(rgba: "#131313")
    open var nightModeMenuBackground = UIColor(rgba: "#1E1E1E")
    open var nightModeSeparatorColor = UIColor(white: 0.5, alpha: 0.2)
    open lazy var mediaOverlayColor: UIColor! = self.tintColor
    
    // Custom actions
    
    /// hide the navigation bar and the bottom status view
    open var hideBars = false
    
    open var scrollDirection: FolioReaderScrollDirection = .vertical
    open var shouldHideNavigation = false
    open var shouldHideNavigationOnTap = true
    open var shouldSkipPagesOnEdges = false
    open var allowSharing = true
    open var enableTTS = true
    
    // Localized strings
    open var localizedHighlightsTitle = NSLocalizedString("Highlights", comment: "")
    open var localizedHighlightsDateFormat = "MMM dd, YYYY | HH:mm"
    open var localizedCopyMenu = NSLocalizedString("Copiar", comment: "")
    open var localizedDiscussionMenu = NSLocalizedString("Criar Discussão", comment: "")
    open var localizedHighlightMenu = NSLocalizedString("Destaque", comment: "")
    open var localizedAnnotationMenu = NSLocalizedString("Anotação", comment: "")
    open var localizedDefineMenu = NSLocalizedString("Definir", comment: "")
    open var localizedPlayMenu = NSLocalizedString("Ouvir", comment: "")
    open var localizedPauseMenu = NSLocalizedString("Pausar", comment: "")
    open var localizedFontMenuNight = NSLocalizedString("Night", comment: "")
    open var localizedPlayerMenuStyle = NSLocalizedString("Estilo", comment: "")
    open var localizedFontMenuDay = NSLocalizedString("Dia", comment: "")
    open var localizedReaderOnePageLeft = NSLocalizedString("1 página restante", comment: "")
    open var localizedReaderManyPagesLeft = NSLocalizedString("páginas restantes", comment: "")
    open var localizedReaderManyMinutes = NSLocalizedString("minutos", comment: "")
    open var localizedReaderOneMinute = NSLocalizedString("1 minuto", comment: "")
    open var localizedReaderLessThanOneMinute = NSLocalizedString("Menos de 1 minuto", comment: "")
    open var localizedShareWebLink: String? = nil
    open var localizedShareChapterSubject = NSLocalizedString("Check out this chapter from", comment: "")
    open var localizedShareHighlightSubject = NSLocalizedString("Notes from", comment: "")
    open var localizedShareAllExcerptsFrom = NSLocalizedString("All excerpts from", comment: "")
    open var localizedShareBy = NSLocalizedString("by", comment: "")}
