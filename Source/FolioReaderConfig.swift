//
//  FolioReaderConfig.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

public enum FolioReaderScrollDirection: Int {
    case vertical
    case horizontal
    
    /**
     The current scroll direction
     
     - returns: Returns `UICollectionViewScrollDirection`
     */
    func collectionViewScrollDirection() -> UICollectionViewScrollDirection {
        switch self {
        case .vertical:
            return .vertical
        case .horizontal:
            return .horizontal
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
    open var scrollDirection: FolioReaderScrollDirection = .vertical
    open var shouldHideNavigation = false
    open var shouldHideNavigationOnTap = true
    open var shouldSkipPagesOnEdges = false
    open var allowSharing = true
    open var enableTTS = true
    
    // Localized strings
    open var localizedHighlightsTitle = NSLocalizedString("Highlights", comment: "")
    open var localizedHighlightsDateFormat = "MMM dd, YYYY | HH:mm"
    open var localizedHighlightMenu = NSLocalizedString("Criar Discussão", comment: "")
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
