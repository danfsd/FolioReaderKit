//
//  FolioReaderNavigationController.swift
//  Pods
//
//  Created by Daniel F. Sampaio on 18/08/16.
//
//

import UIKit

var navigationConfig: FolioReaderNavigationConfig!

public class FolioReaderNavigationConfig: NSObject {
    
    // TODO: fazer com que fique opcional no códigoß
    private var titleViewImage: UIImage!
    private var shouldUseTitleWithImage = false
    
    private var shouldUseGradient = false
    private var gradientStartColor: UIColor!
    private var gradientEndColor: UIColor!
    
    public var shouldUseCustomNavigationBar = false
    public var navigationBarHeight: CGFloat = 44.0
    
    public func setUseTitle(withImage image: UIImage) {
        shouldUseTitleWithImage = true
        titleViewImage = image
    }
    
    public func setUseGradient(startColor: UIColor, endColor: UIColor) {
        shouldUseGradient = true
        gradientStartColor = startColor
        gradientEndColor = endColor
    }
}

public class FolioReaderNavigationController: UINavigationController {
    
    // MARK: - Initializers
    
    override public init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        
        // TODO: setup folioreadernavigationbar
        
        if navigationConfig.shouldUseCustomNavigationBar {
            createNavigationBar()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        // TODO: setup folioreadernavigationbar
        if navigationConfig.shouldUseCustomNavigationBar {
            createNavigationBar()
        }
    }
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        // TODO: setup folioreadernavigationbar
        if navigationConfig.shouldUseCustomNavigationBar {
            createNavigationBar()
        }
    }
    
    override public init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
        
        // TODO: setup folioreadernavigationbar
        if navigationConfig.shouldUseCustomNavigationBar {
            createNavigationBar()
        }
    }
    
    // MARK: - View life cycle
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
//         TODO: setupNavigationBar
        if navigationConfig.shouldUseCustomNavigationBar {
            setupNavigationBar()
        }
    }
    
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // TODO: clean memory
    }
    
    // MARK: - Setup
    
    private func createNavigationBar() {
        let navigationBar = FolioReaderNavigationBar()
        navigationBar.topItem?.title = title
        setValue(navigationBar, forKey: "navigationBar")
    }
    
    public func setupNavigationBar() {
        if navigationConfig.shouldUseTitleWithImage {
            let imageView = UIImageView(frame: CGRectMake(0, 0, 105.0, 20.0))
            imageView.image = navigationConfig.titleViewImage
            imageView.contentMode = .ScaleAspectFit
            navigationBar.topItem?.titleView = imageView
        }
        
        navigationBar.tintColor = UIColor.whiteColor()
        
        if navigationConfig.shouldUseGradient {
            setupGradientBackground()
        }
    }
    
    public func setupGradientBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = navigationBar.bounds
        gradientLayer.colors = [navigationConfig.gradientStartColor!, navigationConfig.gradientEndColor!].map{ $0.CGColor }
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
        
        // Render the gradient to UIImage
        UIGraphicsBeginImageContext(gradientLayer.bounds.size)
        gradientLayer.renderInContext(UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Set the UIImage as background property
        navigationBar.setBackgroundImage(image, forBarMetrics: UIBarMetrics.Default)
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
        
        // TODO: if custom height => initialize()
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        // TODO: if custom height => initialize()
        initialize()
    }
    
    private func initialize() {
        let shift = FolioReaderNavigationBar.heightIncrease / 2
        
        ///Transform all view to shift upward for [shift] point
        self.transform =
            CGAffineTransformMakeTranslation(0, -shift)
    }
    
    // MARK: - View life cycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // TODO: if custom height => setup frame
        let shift = FolioReaderNavigationBar.heightIncrease / 2
        
        ///Move the background down for [shift] point
        let classNamesToReposition: [String] = ["_UINavigationBarBackground"]
        for view: UIView in self.subviews {
            if classNamesToReposition.contains(NSStringFromClass(view.dynamicType)) {
                let bounds: CGRect = self.bounds
                var frame: CGRect = view.frame
                frame.origin.y = bounds.origin.y + shift - 20.0
                frame.size.height = bounds.size.height + 20.0
                view.frame = frame
            }
        }
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(UIScreen.mainScreen().bounds.width, FolioReaderNavigationBar.navigationBarHeight)
    }
    
}
