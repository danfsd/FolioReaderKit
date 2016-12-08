//
//  FolioReaderFontsMenu.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 27/08/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

class FolioReaderFontsMenu: UIViewController, SMSegmentViewDelegate, UIGestureRecognizerDelegate {
    
    var menuView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.clear
        
        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(FolioReaderFontsMenu.tapGesture))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        // Menu view
        menuView = UIView(frame: CGRect(x: 0, y: view.frame.height-170, width: view.frame.width, height: view.frame.height))
        menuView.backgroundColor = isNight(readerConfig.nightModeMenuBackground, UIColor.white)
        menuView.autoresizingMask = .flexibleWidth
        menuView.layer.shadowColor = UIColor.black.cgColor
        menuView.layer.shadowOffset = CGSize(width: 0, height: 0)
        menuView.layer.shadowOpacity = 0.3
        menuView.layer.shadowRadius = 6
        menuView.layer.shadowPath = UIBezierPath(rect: menuView.bounds).cgPath
        menuView.layer.rasterizationScale = UIScreen.main.scale
        menuView.layer.shouldRasterize = true
        view.addSubview(menuView)
        
        let normalColor = UIColor(white: 0.5, alpha: 0.7)
        let selectedColor = readerConfig.tintColor
        let sun = UIImage(readerImageNamed: "icon-sun")
        let moon = UIImage(readerImageNamed: "icon-moon")
        let fontSmall = UIImage(readerImageNamed: "icon-font-small")
        let fontBig = UIImage(readerImageNamed: "icon-font-big")
        
        let sunNormal = sun!.imageTintColor(normalColor).withRenderingMode(.alwaysOriginal)
        let moonNormal = moon!.imageTintColor(normalColor).withRenderingMode(.alwaysOriginal)
        let fontSmallNormal = fontSmall!.imageTintColor(normalColor).withRenderingMode(.alwaysOriginal)
        let fontBigNormal = fontBig!.imageTintColor(normalColor).withRenderingMode(.alwaysOriginal)
        
        let sunSelected = sun!.imageTintColor(selectedColor).withRenderingMode(.alwaysOriginal)
        let moonSelected = moon!.imageTintColor(selectedColor).withRenderingMode(.alwaysOriginal)
        
        // Day night mode
        let dayNight = SMSegmentView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 55),
            separatorColour: readerConfig.nightModeSeparatorColor,
            separatorWidth: 1,
            segmentProperties:  [
                keySegmentTitleFont: UIFont(name: "Avenir-Light", size: 17)!,
                keySegmentOnSelectionColour: UIColor.clear,
                keySegmentOffSelectionColour: UIColor.clear,
                keySegmentOnSelectionTextColour: selectedColor,
                keySegmentOffSelectionTextColour: normalColor,
                keyContentVerticalMargin: 17 as AnyObject
            ])
        dayNight.delegate = self
        dayNight.tag = 1
        dayNight.addSegmentWithTitle(readerConfig.localizedFontMenuDay, onSelectionImage: sunSelected, offSelectionImage: sunNormal)
        dayNight.addSegmentWithTitle(readerConfig.localizedFontMenuNight, onSelectionImage: moonSelected, offSelectionImage: moonNormal)
        dayNight.selectSegmentAtIndex(FolioReader.sharedInstance.nightMode ? 1 : 0)
        menuView.addSubview(dayNight)
        
        
        // Separator
        let line = UIView(frame: CGRect(x: 0, y: dayNight.frame.height+dayNight.frame.origin.y, width: view.frame.width, height: 1))
        line.backgroundColor = readerConfig.nightModeSeparatorColor
        menuView.addSubview(line)

        // Fonts adjust
        let fontName = SMSegmentView(frame: CGRect(x: 15, y: line.frame.height+line.frame.origin.y, width: view.frame.width-30, height: 55),
            separatorColour: UIColor.clear,
            separatorWidth: 0,
            segmentProperties:  [
                keySegmentOnSelectionColour: UIColor.clear,
                keySegmentOffSelectionColour: UIColor.clear,
                keySegmentOnSelectionTextColour: selectedColor,
                keySegmentOffSelectionTextColour: normalColor,
                keyContentVerticalMargin: 17 as AnyObject
            ])
        fontName.delegate = self
        fontName.tag = 2
        fontName.addSegmentWithTitle("Andada", onSelectionImage: nil, offSelectionImage: nil)
        fontName.addSegmentWithTitle("Lato", onSelectionImage: nil, offSelectionImage: nil)
        fontName.addSegmentWithTitle("Lora", onSelectionImage: nil, offSelectionImage: nil)
        fontName.addSegmentWithTitle("Raleway", onSelectionImage: nil, offSelectionImage: nil)
        fontName.segments[0].titleFont = UIFont(name: "Andada-Regular", size: 18)!
        fontName.segments[1].titleFont = UIFont(name: "Lato-Regular", size: 18)!
        fontName.segments[2].titleFont = UIFont(name: "Lora-Regular", size: 18)!
        fontName.segments[3].titleFont = UIFont(name: "Raleway-Regular", size: 18)!
        fontName.selectSegmentAtIndex(FolioReader.sharedInstance.currentFontName)
        menuView.addSubview(fontName)
        
        // Separator 2
        let line2 = UIView(frame: CGRect(x: 0, y: fontName.frame.height+fontName.frame.origin.y, width: view.frame.width, height: 1))
        line2.backgroundColor = readerConfig.nightModeSeparatorColor
        menuView.addSubview(line2)
        
        // Font slider size
        let slider = HADiscreteSlider(frame: CGRect(x: 60, y: line2.frame.origin.y+2, width: view.frame.width-120, height: 55))
        slider.tickStyle = ComponentStyle.rounded
        slider.tickCount = 5
        slider.tickSize = CGSize(width: 8, height: 8)
        
        slider.thumbStyle = ComponentStyle.rounded
        slider.thumbSize = CGSize(width: 28, height: 28)
        slider.thumbShadowOffset = CGSize(width: 0, height: 2)
        slider.thumbShadowRadius = 3
        slider.thumbColor = selectedColor
        
        slider.backgroundColor = UIColor.clear
        slider.tintColor = readerConfig.nightModeSeparatorColor
        slider.minimumValue = 0
        slider.value = CGFloat(FolioReader.sharedInstance.currentFontSize)
        slider.addTarget(self, action: #selector(FolioReaderFontsMenu.sliderValueChanged(_:)), for: UIControlEvents.valueChanged)
        
        // Force remove fill color
        for layer in slider.layer.sublayers! {
            layer.backgroundColor = UIColor.clear.cgColor
        }
        
        menuView.addSubview(slider)
        
        // Font icons
        let fontSmallView = UIImageView(frame: CGRect(x: 20, y: line2.frame.origin.y+14, width: 30, height: 30))
        fontSmallView.image = fontSmallNormal
        fontSmallView.contentMode = UIViewContentMode.center
        menuView.addSubview(fontSmallView)
        
        let fontBigView = UIImageView(frame: CGRect(x: view.frame.width-50, y: line2.frame.origin.y+14, width: 30, height: 30))
        fontBigView.image = fontBigNormal
        fontBigView.contentMode = UIViewContentMode.center
        menuView.addSubview(fontBigView)
        
//        // Separator 3
//        let line3 = UIView(frame: CGRectMake(0, line2.frame.origin.y+56, view.frame.width, 1))
//        line3.backgroundColor = readerConfig.nightModeSeparatorColor
//        menuView.addSubview(line3)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Status Bar
    
    override var prefersStatusBarHidden : Bool {
        return readerConfig.shouldHideNavigationOnTap == true
    }
    
    // MARK: - SMSegmentView delegate
    
    func segmentView(_ segmentView: SMSegmentView, didSelectSegmentAtIndex index: Int) {
        let currentPage = FolioReader.sharedInstance.readerCenter.currentPage
        
        if segmentView.tag == 1 {

//            FolioReader.sharedInstance.nightMode = Bool(index)
            FolioReader.sharedInstance.nightMode = index > 0 ? true : false
            
            let readerCenter = FolioReader.sharedInstance.readerCenter
            
            switch index {
            case 0:
                _ = currentPage?.webView.js("nightMode(false)")
                UIView.animate(withDuration: 0.6, animations: {
                    self.menuView.backgroundColor = UIColor.white
                    readerCenter?.collectionView.backgroundColor = UIColor.white
                    readerCenter?.configureNavBar()
                    readerCenter?.scrollScrubber.updateColors()
                })
                break
            case 1:
                _ = currentPage?.webView.js("nightMode(true)")
                UIView.animate(withDuration: 0.6, animations: {
                    self.menuView.backgroundColor = readerConfig.nightModeMenuBackground
                    readerCenter?.collectionView.backgroundColor = readerConfig.nightModeBackground
                    readerCenter?.configureNavBar()
                    readerCenter?.scrollScrubber.updateColors()
                })
                break
            default:
                break
            }
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: "needRefreshPageMode"), object: nil)
        }
        
        if segmentView.tag == 2 {
            switch index {
            case 0:
                _ = currentPage?.webView.js("setFontName('andada')")
                break
            case 1:
                _ = currentPage?.webView.js("setFontName('lato')")
                break
            case 2:
                _ = currentPage?.webView.js("setFontName('lora')")
                break
            case 3:
                _ = currentPage?.webView.js("setFontName('raleway')")
                break
            default:
                break
            }
            
            FolioReader.sharedInstance.currentFontName = index
        }
    }
    
    // MARK: - Font slider changed
    
    func sliderValueChanged(_ sender: HADiscreteSlider) {
        let currentPage = FolioReader.sharedInstance.readerCenter.currentPage
        let index = Int(sender.value)
        
        switch index {
        case 0:
            _ = currentPage?.webView.js("setFontSize('textSizeOne')")
            break
        case 1:
            _ = currentPage?.webView.js("setFontSize('textSizeTwo')")
            break
        case 2:
            _ = currentPage?.webView.js("setFontSize('textSizeThree')")
            break
        case 3:
            _ = currentPage?.webView.js("setFontSize('textSizeFour')")
            break
        case 4:
            _ = currentPage?.webView.js("setFontSize('textSizeFive')")
            break
        default:
            break
        }
        
        FolioReader.sharedInstance.currentFontSize = index
    }
    
    // MARK: - Gestures
    
    func tapGesture() {
        dismiss()
        
        if readerConfig.shouldHideNavigationOnTap == false {
            FolioReader.sharedInstance.readerCenter.showBars()
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer is UITapGestureRecognizer && touch.view == view {
            return true
        }
        return false
    }
}
