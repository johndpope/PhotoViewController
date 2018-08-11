//
//  PhotoPageController.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

@inlinable
func debuglog(_ items: Any...) -> Void {
  #if DEBUG
  print(items)
  #endif
}

open class PhotoPageController<T: IndexPathSearchable>: UIViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource, ImageZoomProvider {

  public convenience init(modally: Bool, startIndexPath: IndexPath, resources: [T], navigationOrientation: UIPageViewController.NavigationOrientation = .horizontal, interPageSpacing: Double = 10) {
    self.init(nibName: nil, bundle: nil)
    self.modalPresentationCapturesStatusBarAppearance = true
    self.modally = modally
    self.resources = resources
    self.userStartIndexPath = startIndexPath
    self.pagingStartIndexPath = PhotoViewManager.default.pagingIndexPath(form: userStartIndexPath, desiredLength: resources.indexPathLength)
    self.navigationOrientation = navigationOrientation
    self.interPageSpacing = interPageSpacing
  }

  public var normalBackgroundColor: UIColor = UIColor.white

  public var immersedBackgroundColor: UIColor = UIColor.black

  public private(set) var modally: Bool = false

  private var userStartIndexPath: IndexPath = IndexPath(index: -1)

  /// the length is not equal to array's level, usually from user UI
  public var userCurrentIndexPath: IndexPath {
    return PhotoViewManager.default.userIndexPath(template: userStartIndexPath, form: pagingCurrentIndexPath)
  }

  private var pagingCurrentIndexPath: IndexPath = IndexPath(index: -1) {
    didSet {
      didScrollToPage?(PhotoViewManager.default.userIndexPath(template: userStartIndexPath, form: pagingCurrentIndexPath))
    }
  }

  /// the length is equal to array's level
  private var pagingStartIndexPath: IndexPath = IndexPath(index: -1)

  public var statusBarStyle: UIStatusBarStyle = .default

  public var resourcesDeleteDidCompleteBlock: ((_ indexPath: IndexPath, _ removed: MediaResource) -> Void)?

  public var resourcesDeleteHandler: ((_ collection: inout [T], _ indexPath: IndexPath) -> MediaResource)?

  public var didScrollToPage: ((_ indexPath: IndexPath) -> Void)?

  public private(set) var navigationOrientation: UIPageViewController.NavigationOrientation = .horizontal

  public private(set) var interPageSpacing: Double = 0

  public var loop: Bool = true

  private var isStatusBarHidden: Bool = false

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

  private lazy var pageController = UIPageViewController(transitionStyle: UIPageViewController.TransitionStyle.scroll, navigationOrientation: navigationOrientation, options: [.interPageSpacing: NSNumber(value: interPageSpacing)])

  override open func viewDidLoad() {
    super.viewDidLoad()
    PhotoViewManager.default.reloadImmersingState(true)
    changePhotoPageBackgroundColor()
    addPhotoObservers()
    addPage()
  }

  open func addPhotoObservers() -> Void {
    PhotoViewManager.default.notificationCenter.addObserver(self, selector: #selector(handleImmersionStateDidChangeNotification(_:)), name: NSNotification.Name.PhotoViewControllerImmersionDidChange, object: nil)
  }

  @objc func handleImmersionStateDidChangeNotification(_ note: Notification) -> Void {
    changePhotoPageBackgroundColor()
  }

  open func changePhotoPageBackgroundColor() -> Void {
    switch PhotoViewManager.default.immersingState {
    case .immersed:
      self.view.backgroundColor = immersedBackgroundColor
    case .normal:
      self.view.backgroundColor = normalBackgroundColor
    }
  }

  deinit {
    PhotoViewManager.default.notificationCenter.removeObserver(self)
  }

  @available(iOS 9.0, *)
  func addConstraint<R>(fromView: UIView?, toView: UIView?, getAnchor: (UIView) -> NSLayoutAnchor<R>) {
    guard let view1 = fromView else { return }
    guard let view2 = toView else { return }
    getAnchor(view1).constraint(equalTo: getAnchor(view2)).isActive = true
  }

  func addConstraint(fromView: UIView?, toView: UIView?, attribute: NSLayoutConstraint.Attribute) {
    guard let view1 = fromView else { return }
    guard let view2 = toView else { return }
    NSLayoutConstraint(item: view1, attribute: attribute, relatedBy: .equal, toItem: view2, attribute: attribute, multiplier: 1.0, constant: 0.0).isActive = true
  }

  open func addPage() -> Void {
    addChild(pageController)
    pageController.didMove(toParent: self)
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
  }

  open func scrollTo(page: IndexPath, forward: Bool, animated: Bool = false) -> Void {
    pagingCurrentIndexPath = page
    pageController.setViewControllers([photoShow(modally: modally, resource: resources[resource: page])], direction: forward ? .forward : .reverse, animated: animated, completion: nil)
  }

  open func photoShow(modally: Bool, resource: MediaResource) -> UIViewController {
    return PhotoShowController(modally: modally, resource: resource)
  }

  open func indexOf(viewController: UIViewController) -> IndexPath? {
    guard let viewController = viewController as? PhotoShowController else { return nil }
    return resources.firstIndexPath(where: { $0 == viewController.resource })
  }

  open func embed(in viewController: UIViewController?) -> Void {
    viewController?.addChild(self)
    didMove(toParent: viewController)
    viewController?.modalPresentationCapturesStatusBarAppearance = true
  }

  open func removeResource(at indexPath: IndexPath) -> Void {
    assert(resourcesDeleteHandler != nil, "you should implement delete handler")
    assert(resourcesDeleteDidCompleteBlock != nil, "you should implement delete completion")
    var oldFlatList = resources.allIndexPaths(where: { _ in true }, matchFirst: false)
    let oldFlatIndex = oldFlatList.firstIndex(of: indexPath)
    resourcesDeleteDidCompleteBlock?(PhotoViewManager.default.userIndexPath(template: userStartIndexPath, form: indexPath), resourcesDeleteHandler!(&resources, indexPath))
    var newFlatList = resources.allIndexPaths(where: { _ in true }, matchFirst: false)
    let newIndices = Array<Int>(newFlatList.indices)

    var noResource: Bool = false

    defer {
      if noResource {
        if modally {
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



  public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
    guard let index = indexOf(viewController: viewController) else { return nil }
    guard let previousIndex = resources.nextIndexPath(of: index, forward: false, loop: loop) else { return nil }
    debuglog("moving to page \(previousIndex)")
    return photoShow(modally: modally, resource: resources[resource: previousIndex])
  }

  public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
    guard let index = indexOf(viewController: viewController) else { return nil }
    guard let nextIndex = resources.nextIndexPath(of: index, forward: true, loop: loop) else { return nil }
    debuglog("moving to page \(nextIndex)")
    return photoShow(modally: modally, resource: resources[resource: nextIndex])
  }

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

  open override var prefersStatusBarHidden: Bool {
    return currentPhotoViewController?.prefersStatusBarHidden ?? isStatusBarHidden
  }

  open override var preferredStatusBarStyle: UIStatusBarStyle {
    return currentPhotoViewController?.preferredStatusBarStyle ?? statusBarStyle
  }

  public var currentImageViewHidden: Bool {
    set {
      currentImageView?.isHidden = newValue
    }
    get {
      return currentImageView?.isHidden ?? false
    }
  }

  public var currentPhotoViewController: PhotoShowController? {
    return pageController.viewControllers?.compactMap({ $0 as? PhotoShowController}).first
  }

  public var currentImageView: UIImageView? {
    return currentPhotoViewController?.imageView
  }

  public var currentImage: UIImage? {
    return currentImageView?.image
  }

  public var currentImageViewFrame: CGRect? {
    return currentPhotoViewController?.imageViewFrame
  }

  public var dismissalInteractiveController: UIViewControllerInteractiveTransitioning? {
    return currentPhotoViewController?.dismissalInteractiveController
  }

}
