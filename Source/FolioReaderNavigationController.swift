//
//  FolioReaderNavigationController.swift
//  Pods
//
//  Created by Daniel F. Sampaio on 18/08/16.
//
//

import UIKit

var navigationConfig: FolioReaderNavigationConfig!

open class FolioReaderNavigationConfig: NSObject {
    
    // TODO: fazer com que fique opcional no códigoß
    fileprivate var titleViewImage: UIImage!
    fileprivate var shouldUseTitleWithImage = false
    
    fileprivate var shouldUseGradient = false
    fileprivate var gradientStartColor: UIColor!
    fileprivate var gradientEndColor: UIColor!
    
    open var shouldUseCustomNavigationBar = false
    open var navigationBarHeight: CGFloat = 44.0
    
    open func setUseTitle(withImage image: UIImage) {
        shouldUseTitleWithImage = true
        titleViewImage = image
    }
    
    open func setUseGradient(_ startColor: UIColor, endColor: UIColor) {
        shouldUseGradient = true
        gradientStartColor = startColor
        gradientEndColor = endColor
    }
}

open class FolioReaderNavigationController: UINavigationController {
    
    var customNavigationBar: FolioReaderNavigationBar!
    
    // MARK: - Initializers
    
    override public init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        
        if navigationConfig.shouldUseCustomNavigationBar {
            createNavigationBar()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        if navigationConfig.shouldUseCustomNavigationBar {
            createNavigationBar()
        }
    }
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        if navigationConfig.shouldUseCustomNavigationBar {
            createNavigationBar()
        }
    }
    
    override public init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
        
        if navigationConfig.shouldUseCustomNavigationBar {
            createNavigationBar()
        }
    }
    
    // MARK: - View life cycle
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        if navigationConfig.shouldUseCustomNavigationBar {
            setupNavigationBar()
        }
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override open var shouldAutorotate : Bool {
        return visibleViewController!.shouldAutorotate
    }
    
    override open var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return visibleViewController!.supportedInterfaceOrientations
    }
    
    // MARK: - Setup
    
    fileprivate func createNavigationBar() {
        customNavigationBar = FolioReaderNavigationBar()
        customNavigationBar.topItem?.title = title
        setValue(customNavigationBar, forKey: "navigationBar")
    }
    
    open func restoreNavigationBar() {
        navigationBar.tintColor = nil
        navigationBar.setBackgroundImage(nil, for: .default)
    }
    
    open func setupNavigationBar() {
//        if navigationConfig.shouldUseTitleWithImage {
//            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 172.0, height: 36.0))
//            imageView.image = navigationConfig.titleViewImage
//            imageView.contentMode = .scaleAspectFit
//            navigationBar.topItem?.titleView = imageView
//        }
        
        navigationBar.tintColor = UIColor.white
        
        if navigationConfig.shouldUseGradient {
            setupGradientBackground()
        }
    }
    
    open func setupGradientBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = navigationBar.bounds
        gradientLayer.colors = [navigationConfig.gradientStartColor!, navigationConfig.gradientEndColor!].map{ $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
        
        // Render the gradient to UIImage
        UIGraphicsBeginImageContext(gradientLayer.bounds.size)
        gradientLayer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Set the UIImage as background property
        navigationBar.setBackgroundImage(image, for: UIBarMetrics.default)
    }
    
}

class FolioReaderNavigationBar: UINavigationBar {
    
    static var navigationBarHeight: CGFloat {
        return navigationConfig.navigationBarHeight
    }
    
    static var heightIncrease: CGFloat {
        return navigationBarHeight - 44
    }
    
    // MARK: - Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initialize()
    }
    
    fileprivate func initialize() {
        let shift = FolioReaderNavigationBar.heightIncrease / 2
        
        ///Transform all view to shift upward for [shift] point
        self.transform =
            CGAffineTransform(translationX: 0, y: -shift)
    }
    
    // MARK: - View life cycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let shift = FolioReaderNavigationBar.heightIncrease / 2
        
        ///Move the background down for [shift] point
        let versionStr = UIDevice.current.systemVersion
        let index = versionStr.index(versionStr.startIndex, offsetBy: 2)
        let majorVersionStr = versionStr.substring(to: index)
        let majorVersion = Double(majorVersionStr)!
        
        let classNamesToReposition: [String] = majorVersion >= 10.0 ? ["_UIBarBackground"] : ["_UINavigationBarBackground"]
        for view: UIView in self.subviews {
            if classNamesToReposition.contains(NSStringFromClass(type(of: view))) {
                let bounds: CGRect = self.bounds
                var frame: CGRect = view.frame
                frame.origin.y = bounds.origin.y + shift - 20.0
                frame.size.height = bounds.size.height + 20.0
                view.frame = frame
            }
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: UIScreen.main.bounds.width, height: FolioReaderNavigationBar.navigationBarHeight)
    }
    
}
