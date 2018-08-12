//
//  PhotoPageController.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

@inline(__always)
func debuglog(_ items: Any...) -> Void {
  #if DEBUG
  print(items)
  #endif
}

#if swift(>=4.2)
let interPageSpacingKey = UIPageViewController.OptionsKey.interPageSpacing
public typealias PageViewControllerNavigationOrientation = UIPageViewController.NavigationOrientation
public typealias PageViewControllerTransitionStyle = UIPageViewController.TransitionStyle
#else
let interPageSpacingKey = UIPageViewControllerOptionInterPageSpacingKey
public typealias PageViewControllerTransitionStyle = UIPageViewControllerTransitionStyle
public typealias PageViewControllerNavigationOrientation = UIPageViewControllerNavigationOrientation
#endif

open class PhotoPageController<T: IndexPathSearchable>: UIViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource, ImageZoomProvider {

  public private(set) var isModalTransition: Bool = false

  open var normalBackgroundColor: UIColor = UIColor.white

  open var immersiveBackgroundColor: UIColor = UIColor.black

  private var userStartIndexPath: IndexPath = IndexPath(index: -1)

  /// the length is not equal to array's level, usually from user UI
  public var userCurrentIndexPath: IndexPath {
    return PhotoViewManager.default.userIndexPath(template: userStartIndexPath, form: pagingCurrentIndexPath)
  }

  /// the length is equal to array's level
  private var pagingStartIndexPath: IndexPath = IndexPath(index: -1)

  private var pagingCurrentIndexPath: IndexPath = IndexPath(index: -1) {
    didSet {
      didScrollToPageHandler?(PhotoViewManager.default.userIndexPath(template: userStartIndexPath, form: pagingCurrentIndexPath))
    }
  }

  open var statusBarStyle: UIStatusBarStyle = .default {
    didSet {
      setNeedsStatusBarAppearanceUpdate()
    }
  }

  open var resourcesDeleteDidCompleteHandler: ((_ indexPath: IndexPath, _ removed: MediaResource) -> Void)?

  open var resourcesDeleteHandler: ((_ collection: inout [T], _ indexPath: IndexPath) -> MediaResource)?

  open var didScrollToPageHandler: ((_ indexPath: IndexPath) -> Void)?

  public private(set) var navigationOrientation: PageViewControllerNavigationOrientation = .horizontal

  public private(set) var interPageSpacing: Double = 0

  open var loop: Bool = true

  private var resources__: [T] = []

  private let queue: DispatchQueue = DispatchQueue(label: "com.photo.page.controller." + UUID().uuidString)

  private var resources: [T] {
    set {
      queue.sync {
        resources__ = newValue
      }
    }
    get {
      return queue.sync {
        return resources__
      }
    }
  }

  public var currentImageViewHidden: Bool {
    set {
      currentImageView?.isHidden = newValue
    }
    get {
      return currentImageView?.isHidden ?? false
    }
  }

  open var currentPhotoViewController: PhotoShowController? {
    return pageController.viewControllers?.compactMap({ $0 as? PhotoShowController}).first
  }

  open var currentImageView: UIImageView? {
    return currentPhotoViewController?.imageView
  }

  open var currentImage: UIImage? {
    return currentImageView?.image
  }

  open var currentImageViewFrame: CGRect? {
    return currentPhotoViewController?.imageViewFrame
  }

  open var dismissalInteractiveController: UIViewControllerInteractiveTransitioning? {
    return currentPhotoViewController?.dismissalInteractiveController
  }

  private lazy var pageController = UIPageViewController(transitionStyle: PageViewControllerTransitionStyle.scroll, navigationOrientation: navigationOrientation, options: [interPageSpacingKey: NSNumber(value: interPageSpacing)])

  // MARK: - init

  public convenience init(isModalTransition: Bool, startIndexPath: IndexPath, resources: [T], navigationOrientation: PageViewControllerNavigationOrientation = .horizontal, interPageSpacing: Double = 10) {
    self.init(nibName: nil, bundle: nil)
    self.modalPresentationCapturesStatusBarAppearance = true
    self.isModalTransition = isModalTransition
    self.resources = resources
    self.userStartIndexPath = startIndexPath
    self.pagingStartIndexPath = PhotoViewManager.default.pagingIndexPath(form: userStartIndexPath, desiredLength: resources.indexPathLength)
    self.navigationOrientation = navigationOrientation
    self.interPageSpacing = interPageSpacing
  }

  // MARK: - viewDidLoad

  override open func viewDidLoad() {
    super.viewDidLoad()
    PhotoViewManager.default.reloadImmersiveMode(true)
    changePhotoPageBackgroundColor()
    addImmersiveModeObservers()
    addPage()
  }

  // MARK: - ImmersiveMode

  open func addImmersiveModeObservers() -> Void {
    PhotoViewManager.default.notificationCenter.addObserver(self, selector: #selector(handleImmersiveModeDidChangeNotification(_:)), name: NSNotification.Name.PhotoViewControllerImmersiveModeDidChange, object: nil)
  }

  @objc func handleImmersiveModeDidChangeNotification(_ note: Notification) -> Void {
    changePhotoPageBackgroundColor()
  }

  open func changePhotoPageBackgroundColor() -> Void {
    switch PhotoViewManager.default.immersiveMode {
    case .immersive:
      self.view.backgroundColor = immersiveBackgroundColor
    case .normal:
      self.view.backgroundColor = normalBackgroundColor
    }
  }

  // MARK: - Auto Layout

  @available(iOS 9.0, *)
  func addConstraint<R>(fromView: UIView?, toView: UIView?, getAnchor: (UIView) -> NSLayoutAnchor<R>) {
    guard let view1 = fromView else { return }
    guard let view2 = toView else { return }
    getAnchor(view1).constraint(equalTo: getAnchor(view2)).isActive = true
  }

  #if swift(>=4.2)
  typealias LayoutConstraintAttribute = NSLayoutConstraint.Attribute
  #else
  typealias LayoutConstraintAttribute = NSLayoutAttribute
  #endif
  func addConstraint(fromView: UIView?, toView: UIView?, attribute: LayoutConstraintAttribute) {
    guard let view1 = fromView else { return }
    guard let view2 = toView else { return }
    NSLayoutConstraint(item: view1, attribute: attribute, relatedBy: .equal, toItem: view2, attribute: attribute, multiplier: 1.0, constant: 0.0).isActive = true
  }

  // MARK: - Add UIPageViewController

  open func addPage() -> Void {
    #if swift(>=4.2)
    addChild(pageController)
    pageController.didMove(toParent: self)
    #else
    addChildViewController(pageController)
    pageController.didMove(toParentViewController: self)
    #endif
    view.addSubview(pageController.view)
    pageController.view.backgroundColor = UIColor.clear
    if #available(iOS 9.0, *) {
      addConstraint(fromView: pageController.view, toView: view, getAnchor: { $0.topAnchor })
      addConstraint(fromView: pageController.view, toView: view, getAnchor: { $0.bottomAnchor })
      addConstraint(fromView: pageController.view, toView: view, getAnchor: { $0.leftAnchor })
      addConstraint(fromView: pageController.view, toView: view, getAnchor: { $0.rightAnchor })
    } else {
      addConstraint(fromView: pageController.view, toView: view, attribute: .top)
      addConstraint(fromView: pageController.view, toView: view, attribute: .bottom)
      addConstraint(fromView: pageController.view, toView: view, attribute: .left)
      addConstraint(fromView: pageController.view, toView: view, attribute: .right)
      // Fallback on earlier versions
    }
    pageController.delegate = self
    pageController.dataSource = self
    scrollTo(page: pagingStartIndexPath, forward: true)
    if #available(iOS 11.0, *) {
      
    } else {
      automaticallyAdjustsScrollViewInsets = false
      pageController.automaticallyAdjustsScrollViewInsets = false
    }
  }

  // MARK: - navigate to page at index

  open func scrollTo(page: IndexPath, forward: Bool, animated: Bool = false) -> Void {
    pagingCurrentIndexPath = page
    pageController.setViewControllers([photoShow(modally: isModalTransition, resource: resources[resource: page])], direction: forward ? .forward : .reverse, animated: animated, completion: nil)
  }

  // MARK: - single photo

  open func photoShow(modally isModalTransition: Bool, resource: MediaResource) -> UIViewController {
    return PhotoShowController(isModalTransition: isModalTransition, resource: resource)
  }

  // MARK: - get index

  open func indexOf(viewController: UIViewController) -> IndexPath? {
    guard let viewController = viewController as? PhotoShowController else { return nil }
    return resources.firstIndexPath(where: { $0 == viewController.resource })
  }

  // MARK: - embed in parent controller

  open func embed(in viewController: UIViewController?) -> Void {
    #if swift(>=4.2)
    viewController?.addChild(self)
    didMove(toParent: viewController)
    #else
    viewController?.addChildViewController(self)
    didMove(toParentViewController: viewController)
    #endif
    viewController?.modalPresentationCapturesStatusBarAppearance = true
    if #available(iOS 11.0, *) {

    } else {
      viewController?.automaticallyAdjustsScrollViewInsets = false
    }
  }

  // MARK: - delete

  open func removeResource(at indexPath: IndexPath) -> Void {
    assert(resourcesDeleteDidCompleteHandler != nil, "you should implement delete completion")
    var oldFlatList = resources.allIndexPaths(where: { _ in true }, matchFirst: false)
    #if swift(>=4.2)
    let oldFlatIndex = oldFlatList.firstIndex(of: indexPath)
    #else
    let oldFlatIndex = oldFlatList.index(of: indexPath)
    #endif
    resourcesDeleteDidCompleteHandler?(PhotoViewManager.default.userIndexPath(template: userStartIndexPath, form: indexPath), resourcesDeleteHandler?(&resources, indexPath) ?? resources.removeItemAt(indexPath: indexPath))
    var newFlatList = resources.allIndexPaths(where: { _ in true }, matchFirst: false)
    let newIndices = Array<Int>(newFlatList.indices)

    var noResource: Bool = false

    defer {
      if noResource {
        if isModalTransition {
          dismiss(animated: true, completion: nil)
        } else {
          navigationController?.popViewController(animated: true)
        }
      }
    }

    if let oldFlatIndex = oldFlatIndex {
      if newIndices.contains(oldFlatIndex) {
        let rearrangedIndex = IndexPath(indexes: newFlatList[oldFlatIndex])
        scrollTo(page: rearrangedIndex, forward: true, animated: true)
      } else if newIndices.contains(oldFlatIndex - 1) {
        let rearrangedIndex = IndexPath(indexes: newFlatList[oldFlatIndex-1])
        scrollTo(page: rearrangedIndex, forward: false, animated: true)
      } else {
        assert(newIndices.count == 0, "expect no resource")
        noResource = true
        return
      }
    } else {
      fatalError("the oldFlatIndex should never be nil")
    }
  }


  public func removeCurrentResource() {
    removeResource(at: pagingCurrentIndexPath)
  }


  // MARK: - UIPageViewControllerDataSource

  public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
    guard let index = indexOf(viewController: viewController) else { return nil }
    guard let previousIndex = resources.nextIndexPath(of: index, forward: false, loop: loop) else { return nil }
    debuglog("moving to page \(previousIndex)")
    return photoShow(modally: isModalTransition, resource: resources[resource: previousIndex])
  }

  public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
    guard let index = indexOf(viewController: viewController) else { return nil }
    guard let nextIndex = resources.nextIndexPath(of: index, forward: true, loop: loop) else { return nil }
    debuglog("moving to page \(nextIndex)")
    return photoShow(modally: isModalTransition, resource: resources[resource: nextIndex])
  }

  // MARK: - UIPageViewControllerDelegate

  public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
    if let viewController = currentPhotoViewController, let index = indexOf(viewController: viewController) {
      pagingCurrentIndexPath = index
    }
  }

  public func pageViewControllerSupportedInterfaceOrientations(_ pageViewController: UIPageViewController) -> UIInterfaceOrientationMask {
    return currentPhotoViewController?.supportedInterfaceOrientations ?? supportedInterfaceOrientations
  }

  public func pageViewControllerPreferredInterfaceOrientationForPresentation(_ pageViewController: UIPageViewController) -> UIInterfaceOrientation {
    return currentPhotoViewController?.preferredInterfaceOrientationForPresentation ?? preferredInterfaceOrientationForPresentation
  }

  // MARK: - UIViewController


  open override var prefersStatusBarHidden: Bool {
    return currentPhotoViewController?.prefersStatusBarHidden ?? false
  }

  open override var preferredStatusBarStyle: UIStatusBarStyle {
    return currentPhotoViewController?.preferredStatusBarStyle ?? statusBarStyle
  }

  // MARK: - deinit


  deinit {
    PhotoViewManager.default.notificationCenter.removeObserver(self)
  }

}
