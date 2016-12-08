//
//  FolioReaderPageIndicator.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 10/09/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import CoreData

class FolioReaderPageIndicator: UIView {
    var pagesLabel: UILabel!
    var minutesLabel: UILabel!
    var totalMinutes: Int!
    var totalPages: Int!
    var currentPage: Int = 1 {
        didSet { self.reloadViewWithPage(self.currentPage) }
    }
    
    override init(frame: CGRect) {
//        print("PageIndicator.\(#function)")
        super.init(frame: frame)
        
        let color = isNight(readerConfig.nightModeBackground, UIColor.white)
        backgroundColor = color
        layer.shadowColor = color.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -6)
        layer.shadowOpacity = 1
        layer.shadowRadius = 4
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
        layer.rasterizationScale = UIScreen.main.scale
        layer.shouldRasterize = true
        
        pagesLabel = UILabel(frame: CGRect.zero)
        pagesLabel.font = UIFont(name: "Avenir-Light", size: 10)!
        pagesLabel.textAlignment = NSTextAlignment.right
        addSubview(pagesLabel)
        
        minutesLabel = UILabel(frame: CGRect.zero)
        minutesLabel.font = UIFont(name: "Avenir-Light", size: 10)!
        minutesLabel.textAlignment = NSTextAlignment.right
//        minutesLabel.alpha = 0
        addSubview(minutesLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func reloadView(_ updateShadow: Bool) {
//        print("PageIndicator.\(#function)")
        minutesLabel.sizeToFit()
        pagesLabel.sizeToFit()
        
        let fullW = pagesLabel.frame.width + minutesLabel.frame.width
        minutesLabel.frame.origin = CGPoint(x: frame.width/2-fullW/2, y: 2)
        pagesLabel.frame.origin = CGPoint(x: minutesLabel.frame.origin.x+minutesLabel.frame.width, y: 2)
        
        if updateShadow {
            layer.shadowPath = UIBezierPath(rect: bounds).cgPath
            
            // Update colors
            let color = isNight(readerConfig.nightModeBackground, UIColor.white)
            backgroundColor = color
            layer.shadowColor = color.cgColor
            
            minutesLabel.textColor = isNight(UIColor(white: 5, alpha: 0.3), UIColor(white: 0, alpha: 0.6))
            pagesLabel.textColor = isNight(UIColor(white: 5, alpha: 0.6), UIColor(white: 0, alpha: 0.9))
        }
    }
    
    fileprivate func reloadViewWithPage(_ page: Int) {
//        print("PageIndicator.\(#function)")
        let pagesRemaining = totalPages-page
        
        if pagesRemaining == 1 {
            pagesLabel.text = " \(readerConfig.localizedReaderOnePageLeft)."
        } else {
            pagesLabel.text = " \(pagesRemaining) \(readerConfig.localizedReaderManyPagesLeft)."
        }
        
        FolioReader.sharedInstance.readerContainer.updateReadInfos(totalPages: totalPages,
                                                                   actualPage: page,chapter: FolioReader.sharedInstance.readerCenter.currentPage.pageNumber)

    
        let minutesRemaining = Int(ceil(CGFloat((pagesRemaining * totalMinutes)/totalPages)))
        if minutesRemaining > 1 {
            minutesLabel.text = "\(minutesRemaining) "+readerConfig.localizedReaderManyMinutes+" ·"
        } else if minutesRemaining == 1 {
            minutesLabel.text = readerConfig.localizedReaderOneMinute+" ·"
        } else {
            minutesLabel.text = readerConfig.localizedReaderLessThanOneMinute+" ·"
        }
        
        reloadView(false)
    }
}
