//
//  FolioReaderKit.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Internal constants for devices

internal let isPad = UIDevice.current.userInterfaceIdiom == .pad
internal let isPhone = UIDevice.current.userInterfaceIdiom == .phone

// MARK: - Internal constants

internal let kApplicationDocumentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
internal let kCurrentTextAlignment = "com.folioreader.kCurrentTextAlignment"
internal let kCurrentFontFamily = "com.folioreader.kCurrentFontFamily"
internal let kCurrentFontSize = "com.folioreader.kCurrentFontSize"
internal let kCurrentAudioRate = "com.folioreader.kCurrentAudioRate"
internal let kCurrentHighlightStyle = "com.folioreader.kCurrentHighlightStyle"
internal var kCurrentMediaOverlayStyle = "com.folioreader.kMediaOverlayStyle"
// TODO: add last offset for orientation

internal let kNightMode = "com.folioreader.kNightMode"
internal let kCurrentTOCMenu = "com.folioreader.kCurrentTOCMenu"
internal let kMigratedToRealm = "com.folioreader.kMigratedToRealm"
internal let kHighlightRange = 30
internal var kBookId: String!

/**
 Defines the media overlay and TTS selection
 
 - Default:   The background is colored
 - Underline: The underlined is colored
 - TextColor: The text is colored
 */
enum MediaOverlayStyle: Int {
    case `default`
    case underline
    case textColor
    
    init () {
        self = .default
    }
    
    func className() -> String {
        return "mediaOverlayStyle\(self.rawValue)"
    }
}

/**
*  Main Library class with some useful constants and methods
*/
open class FolioReader : NSObject {
    static let sharedInstance = FolioReader()
    static let defaults = UserDefaults.standard
    weak var readerCenter: FolioReaderCenter!
    weak var readerContainer: FolioReaderBaseContainer!
    weak var readerAudioPlayer: FolioReaderAudioPlayer!
    var isReaderOpen = false
    var isReaderReady = false
    
    fileprivate override init() {
        let isMigrated = FolioReader.defaults.bool(forKey: kMigratedToRealm)
        if !isMigrated {
            Highlight.migrateUserDataToRealm()
        }
    }
    
    var nightMode: Bool {
        get { return FolioReader.defaults.bool(forKey: kNightMode) }
        set (value) {
            FolioReader.defaults.set(value, forKey: kNightMode)
        }
    }
    
    var currentTextAlignement: Int {
        get { return FolioReader.defaults.value(forKey: kCurrentTextAlignment) as! Int }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kCurrentTextAlignment)
        }
    }
    
    var currentFontName: Int {
        get { return FolioReader.defaults.value(forKey: kCurrentFontFamily) as! Int }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kCurrentFontFamily)
        }
    }
    
    var currentFontSize: Int {
        get { return FolioReader.defaults.value(forKey: kCurrentFontSize) as! Int }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kCurrentFontSize)
        }
    }
    
    var currentAudioRate: Int {
        get { return FolioReader.defaults.value(forKey: kCurrentAudioRate) as! Int }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kCurrentAudioRate)
        }
    }

    var currentHighlightStyle: Int {
        get { return FolioReader.defaults.value(forKey: kCurrentHighlightStyle) as! Int }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kCurrentHighlightStyle)
        }
    }
    
    var currentMediaOverlayStyle: MediaOverlayStyle {
        get { return MediaOverlayStyle(rawValue: FolioReader.defaults.value(forKey: kCurrentMediaOverlayStyle) as! Int)! }
        set (value) {
            FolioReader.defaults.setValue(value.rawValue, forKey: kCurrentMediaOverlayStyle)
        }
    }
    
    // MARK: - Get Cover Image
    
    /**
     Read Cover Image and Return an IUImage
     */
    
    open class func getCoverImage(_ epubPath: String) -> UIImage? {
        return FREpubParser().parseCoverImage(epubPath)
    }

    // MARK: - Present Folio Reader
    
    /**
     Present a Folio Reader for a Parent View Controller.
    */
    open class func presentReader(_ parentViewController: UIViewController, withEpubPath epubPath: String, andConfig config: FolioReaderConfig, andNavigationConfig navigationConfig: FolioReaderNavigationConfig, shouldRemoveEpub: Bool = true, animated: Bool = true, completion: (() -> Void)? = nil) {
        let reader = FolioReaderContainer(config: config, navigationConfig: navigationConfig, epubPath: epubPath, removeEpub: shouldRemoveEpub)
        FolioReader.sharedInstance.readerContainer = reader
        parentViewController.present(reader, animated: animated, completion: completion)
    }
    
    /**
     Push a Folio Reader into the `parentViewController` navigation controller.
     */
    open class func pushReader(_ parentViewController: UIViewController, withEpubPath epubPath: String, andConfig config: FolioReaderConfig, andNavigationConfig navigationConfig: FolioReaderNavigationConfig, shouldRemoveEpub: Bool = true, animated: Bool = true) {
        let reader = FolioReaderContainer(config: config,  navigationConfig: navigationConfig, epubPath: epubPath, removeEpub: shouldRemoveEpub)
        FolioReader.sharedInstance.readerContainer = reader
        parentViewController.navigationController?.setNavigationBarHidden(true, animated: false)
        parentViewController.navigationController?.pushViewController(reader, animated: true)
    }
    
    /**
     Present a custom Folio Reader for a Parent View Controller.
     */
    open class func presentReader(_ customReader: FolioReaderBaseContainer, parentViewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        FolioReader.sharedInstance.readerContainer = customReader
        parentViewController.present(customReader, animated: animated, completion: completion)
    }
    
    /**
     Push a custom Folio Reader into the `parentViewController` navigation controller.
     */
    open class func pushReader(_ customReader: FolioReaderBaseContainer, parentViewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        FolioReader.sharedInstance.readerContainer = customReader
        parentViewController.navigationController?.setNavigationBarHidden(true, animated: false)
        parentViewController.navigationController?.pushViewController(customReader, animated: true)
    }
    
    // MARK: - Application State
    
    /**
     Called when the application will resign active
    */
    open class func applicationWillResignActive() {
        saveReaderState()
    }
    
    /**
     Called when the application will terminate
    */
    open class func applicationWillTerminate() {
        saveReaderState()
    }
    
    /**
     Save Reader state, book, page and scroll are saved
    */
    class func saveReaderState() {
        if FolioReader.sharedInstance.isReaderOpen {
            if let currentPage = FolioReader.sharedInstance.readerCenter.currentPage {
                let position = [
                    "pageNumber": currentPageNumber,
                    "pageOffsetX": currentPage.webView.scrollView.contentOffset.x,
                    "pageOffsetY": currentPage.webView.scrollView.contentOffset.y
                ] as [String : Any]
                
                FolioReader.defaults.set(position, forKey: kBookId)
            }
        }
    }
    
    open class func getHighlightCount(_ bookId: String) -> Int {
        return Highlight.allByBookId((bookId as NSString).deletingPathExtension).count
    }
    
    class func close() {
        FolioReader.saveReaderState()
        FolioReader.sharedInstance.isReaderOpen = false
        FolioReader.sharedInstance.isReaderReady = false
        FolioReader.sharedInstance.readerAudioPlayer.stop(true)
        FolioReader.defaults.set(0, forKey: kCurrentTOCMenu)
    }
}

// MARK: - Global Functions

func isNight<T> (_ f: T, _ l: T) -> T {
    return FolioReader.sharedInstance.nightMode ? f : l
}

// MARK: - Scroll Direction Functions

func isVerticalDirection<T> (_ f: T, _ l: T) -> T {
    return readerConfig.scrollDirection == .vertical ? f : l
}

extension UICollectionViewScrollDirection {
    static func direction() -> UICollectionViewScrollDirection {
        return isVerticalDirection(.vertical, .horizontal)
    }
}

extension UICollectionViewScrollPosition {
    static func direction() -> UICollectionViewScrollPosition {
        return isVerticalDirection(.top, .left)
    }
}

extension CGPoint {
    func forDirection() -> CGFloat {
        return isVerticalDirection(self.y, self.x)
    }
}

extension CGSize {
    func forDirection() -> CGFloat {
        return isVerticalDirection(self.height, self.width)
    }
}

extension CGRect {
    func forDirection() -> CGFloat {
        return isVerticalDirection(self.height, self.width)
    }
}

extension ScrollDirection {
    static func negative() -> ScrollDirection {
        return isVerticalDirection(.down, .right)
    }
    
    static func positive() -> ScrollDirection {
        return isVerticalDirection(.up, .left)
    }
}

/**
 Delay function
 From: http://stackoverflow.com/a/24318861/517707
 
 - parameter delay:   Delay in seconds
 - parameter closure: Closure
 */
func delay(_ delay:Double, closure:@escaping ()->()) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}


// MARK: - Extensions

internal extension Bundle {
    class func frameworkBundle() -> Bundle {
        return Bundle(for: FolioReader.self)
    }
}

internal extension UIColor {
    convenience init(rgba: String) {
        var red:   CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue:  CGFloat = 0.0
        var alpha: CGFloat = 1.0
        
        if rgba.hasPrefix("#") {
            let index   = rgba.characters.index(rgba.startIndex, offsetBy: 1)
            let hex     = rgba.substring(from: index)
            let scanner = Scanner(string: hex)
            var hexValue: CUnsignedLongLong = 0
            if scanner.scanHexInt64(&hexValue) {
                switch (hex.characters.count) {
                case 3:
                    red   = CGFloat((hexValue & 0xF00) >> 8)       / 15.0
                    green = CGFloat((hexValue & 0x0F0) >> 4)       / 15.0
                    blue  = CGFloat(hexValue & 0x00F)              / 15.0
                    break
                case 4:
                    red   = CGFloat((hexValue & 0xF000) >> 12)     / 15.0
                    green = CGFloat((hexValue & 0x0F00) >> 8)      / 15.0
                    blue  = CGFloat((hexValue & 0x00F0) >> 4)      / 15.0
                    alpha = CGFloat(hexValue & 0x000F)             / 15.0
                    break
                case 6:
                    red   = CGFloat((hexValue & 0xFF0000) >> 16)   / 255.0
                    green = CGFloat((hexValue & 0x00FF00) >> 8)    / 255.0
                    blue  = CGFloat(hexValue & 0x0000FF)           / 255.0
                    break
                case 8:
                    red   = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
                    green = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
                    blue  = CGFloat((hexValue & 0x0000FF00) >> 8)  / 255.0
                    alpha = CGFloat(hexValue & 0x000000FF)         / 255.0
                    break
                default:
                    print("Invalid RGB string, number of characters after '#' should be either 3, 4, 6 or 8", terminator: "")
                    break
                }
            } else {
                print("Scan hex error")
            }
        } else {
            print("Invalid RGB string, missing '#' as prefix", terminator: "")
        }
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }

    /**
     Hex string of a UIColor instance.

     - parameter rgba: Whether the alpha should be included.
     */
    // from: https://github.com/yeahdongcn/UIColor-Hex-Swift
    func hexString(_ includeAlpha: Bool) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)

        if (includeAlpha) {
            return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        } else {
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
    }

    // MARK: - color shades
    // https://gist.github.com/mbigatti/c6be210a6bbc0ff25972

    func highlightColor() -> UIColor {

        var hue : CGFloat = 0
        var saturation : CGFloat = 0
        var brightness : CGFloat = 0
        var alpha : CGFloat = 0

        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: 0.30, brightness: 1, alpha: alpha)
        } else {
            return self;
        }

    }

    /**
     Returns a lighter color by the provided percentage

     :param: lighting percent percentage
     :returns: lighter UIColor
     */
    func lighterColor(_ percent : Double) -> UIColor {
        return colorWithBrightnessFactor(CGFloat(1 + percent));
    }

    /**
     Returns a darker color by the provided percentage

     :param: darking percent percentage
     :returns: darker UIColor
     */
    func darkerColor(_ percent : Double) -> UIColor {
        return colorWithBrightnessFactor(CGFloat(1 - percent));
    }

    /**
     Return a modified color using the brightness factor provided

     :param: factor brightness factor
     :returns: modified color
     */
    func colorWithBrightnessFactor(_ factor: CGFloat) -> UIColor {
        var hue : CGFloat = 0
        var saturation : CGFloat = 0
        var brightness : CGFloat = 0
        var alpha : CGFloat = 0

        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness * factor, alpha: alpha)
        } else {
            return self;
        }
    }
}

internal extension String {
    /// Truncates the string to length number of characters and
    /// appends optional trailing string if longer
    func truncate(_ length: Int, trailing: String? = nil) -> String {
        if self.characters.count > length {
            return self.substring(to: self.characters.index(self.startIndex, offsetBy: length)) + (trailing ?? "")
        } else {
            return self
        }
    }
    
    func stripHtml() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    
    func stripLineBreaks() -> String {
        return self.replacingOccurrences(of: "\n", with: "", options: .regularExpression)
    }

    /**
     Converts a clock time such as `0:05:01.2` to seconds (`Double`)

     Looks for media overlay clock formats as specified [here][1]

     - Note: this may not be the  most efficient way of doing this. It can be improved later on.

     - Returns: seconds as `Double`

     [1]: http://www.idpf.org/epub/301/spec/epub-mediaoverlays.html#app-clock-examples
    */
    func clockTimeToSeconds() -> Double {

        let val = self.trimmingCharacters(in: CharacterSet.whitespaces)

        if( val.isEmpty ){ return 0 }

        let formats = [
            "HH:mm:ss.SSS"  : "^\\d{1,2}:\\d{2}:\\d{2}\\.\\d{1,3}$",
            "HH:mm:ss"      : "^\\d{1,2}:\\d{2}:\\d{2}$",
            "mm:ss.SSS"     : "^\\d{1,2}:\\d{2}\\.\\d{1,3}$",
            "mm:ss"         : "^\\d{1,2}:\\d{2}$",
            "ss.SSS"         : "^\\d{1,2}\\.\\d{1,3}$",
        ]

        // search for normal duration formats such as `00:05:01.2`
        for (format, pattern) in formats {

            if val.range(of: pattern, options: .regularExpression) != nil {

                let formatter = DateFormatter()
                formatter.dateFormat = format
                let time = formatter.date(from: val)

                if( time == nil ){ return 0 }

                formatter.dateFormat = "ss.SSS"
                let seconds = (formatter.string(from: time!) as NSString).doubleValue

                formatter.dateFormat = "mm"
                let minutes = (formatter.string(from: time!) as NSString).doubleValue

                formatter.dateFormat = "HH"
                let hours = (formatter.string(from: time!) as NSString).doubleValue

                return seconds + (minutes*60) + (hours*60*60)
            }
        }

        // if none of the more common formats match, check for other possible formats

        // 2345ms
        if val.range(of: "^\\d+ms$", options: .regularExpression) != nil{
            return (val as NSString).doubleValue / 1000.0
        }

        // 7.25h
        if val.range(of: "^\\d+(\\.\\d+)?h$", options: .regularExpression) != nil {
            return (val as NSString).doubleValue * 60 * 60
        }

        // 13min
        if val.range(of: "^\\d+(\\.\\d+)?min$", options: .regularExpression) != nil {
            return (val as NSString).doubleValue * 60
        }

        return 0
    }

    func clockTimeToMinutesString() -> String {

        let val = clockTimeToSeconds()

        let min = floor(val / 60)
        let sec = floor(val.truncatingRemainder(dividingBy: 60))

        return String(format: "%02.f:%02.f", min, sec)
    }

}

internal extension UIImage {
    convenience init?(readerImageNamed: String) {
        self.init(named: readerImageNamed, in: Bundle.frameworkBundle(), compatibleWith: nil)
    }
    
    /**
     Forces the image to be colored with Reader Config tintColor
     
     - returns: Returns a colored image
     */
    func ignoreSystemTint() -> UIImage {
        return self.imageTintColor(readerConfig.tintColor).withRenderingMode(.alwaysOriginal)
    }
    
    /**
     Colorize the image with a color
     
     - parameter tintColor: The input color
     - returns: Returns a colored image
     */
    func imageTintColor(_ tintColor: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        
        let context = UIGraphicsGetCurrentContext()! as CGContext
        context.translateBy(x: 0, y: self.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.setBlendMode(CGBlendMode.normal)
        
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height) as CGRect
        context.clip(to: rect, mask: self.cgImage!)
        tintColor.setFill()
        context.fill(rect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()! as UIImage
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    /**
     Generate a image with a color
     
     - parameter color: The input color
     - returns: Returns a colored image
     */
    class func imageWithColor(_ color: UIColor?) -> UIImage! {
        let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        
        if let color = color {
            color.setFill()
        } else {
            UIColor.white.setFill()
        }
        
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}

internal extension UIViewController {
    
    func setCloseButton() {
        let closeImage = UIImage(readerImageNamed: "icon-navbar-close")?.ignoreSystemTint()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: closeImage, style: .plain, target: self, action: #selector(dismiss as (Void) -> Void))
    }
    
    func pop() {
        DispatchQueue.main.async {
            _ = self.navigationController?.popViewController(animated: true)
        }
    }
    
    func dismiss() {
        dismiss(nil)
    }
    
    func dismiss(_ completion: (() -> Void)?) {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: {
                completion?()
            })
        }
    }
    
    // MARK: - NavigationBar
    
    func setTransparentNavigation() {
        let navBar = self.navigationController?.navigationBar
        navBar?.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navBar?.hideBottomHairline()
        navBar?.isTranslucent = true
    }
    
    func setTranslucentNavigation(_ translucent: Bool = true, color: UIColor, tintColor: UIColor = UIColor.white, titleColor: UIColor = UIColor.black, andFont font: UIFont = UIFont.systemFont(ofSize: 17)) {
        let navBar = self.navigationController?.navigationBar
        navBar?.setBackgroundImage(UIImage.imageWithColor(color), for: UIBarMetrics.default)
        navBar?.showBottomHairline()
        navBar?.isTranslucent = translucent
        navBar?.tintColor = tintColor
        navBar?.titleTextAttributes = [NSForegroundColorAttributeName: titleColor, NSFontAttributeName: font]
    }
}

internal extension UINavigationBar {
    
    func hideBottomHairline() {
        let navigationBarImageView = hairlineImageViewInNavigationBar(self)
        navigationBarImageView!.isHidden = true
    }
    
    func showBottomHairline() {
        let navigationBarImageView = hairlineImageViewInNavigationBar(self)
        navigationBarImageView!.isHidden = false
    }
    
    fileprivate func hairlineImageViewInNavigationBar(_ view: UIView) -> UIImageView? {
        if view.isKind(of: UIImageView.self) && view.bounds.height <= 1.0 {
            return (view as! UIImageView)
        }
        
        let subviews = (view.subviews )
        for subview: UIView in subviews {
            if let imageView: UIImageView = hairlineImageViewInNavigationBar(subview) {
                return imageView
            }
        }
        return nil
    }
}

extension UINavigationController {
    
    open override var preferredStatusBarStyle : UIStatusBarStyle {
        if let vc = visibleViewController {
            return vc.preferredStatusBarStyle
        }
        return .default
    }
}

internal extension Array {
    
    /**
     Return index if is safe, if not return nil
     http://stackoverflow.com/a/30593673/517707
     */
    subscript(safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}
