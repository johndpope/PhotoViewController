//
//  PhotoPageController.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

open class PhotoPageController<T: IndexPathSearchable>: UIViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource, LargePhotoViewProvider, ImageZoomForceTouchProvider, UINavigationControllerDelegateHolder {

  public var restoreNavigationControllerDelegateHandler: ((UINavigationControllerDelegate?) -> Void)?

  public var navigationControllerDelegateStorage: UINavigationControllerDelegate?

  public var isForceTouching: Bool = false {
    didSet {
      let size = PhotoViewManager.default.contentSize(forPreviewing: self.isForceTouching, resourceSize: self.currentImageViewFrame?.size)
      self.pageController.preferredContentSize = size
      nextForceTouchReceiver?.isForceTouching = isForceTouching
    }
  }

  public var nextForceTouchReceiver: ImageZoomForceTouchProvider? {
    return currentPhotoViewController
  }

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

  open var tryDeleteResourceHandler: ((_ indexPath: IndexPath, _ completion: @escaping (Bool) -> Void) -> Void)?

  open var deleteResourceHandler: ((_ collection: inout [T], _ indexPath: IndexPath) -> MediaResource)?

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

  open var dismissalInteractiveController: ZoomOutAnimatedInteractiveController? {
    return currentPhotoViewController?.dismissalInteractiveController
  }

  #if swift(>=4.2)
  let interPageSpacingKey = UIPageViewController.OptionsKey.interPageSpacing
  #else
  let interPageSpacingKey = UIPageViewControllerOptionInterPageSpacingKey
  #endif

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
    PhotoViewManager.default.notificationCenter.addObserver(self, selector: #selector(handleImmersiveModeDidChangeNotification(_:)), name: PhotoViewManager.immersiveModeDidChange, object: nil)
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
    pageController.view.inset(inView: view)
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
    guard resources.allIndexPaths(where: { _ in true }, matchFirst: false).contains(indexPath) else {
      return
    }
    let resource = resources[resource: indexPath]
    guard !resource.removing else {
      return
    }
    resource.removing = true
    assert(tryDeleteResourceHandler != nil, "you should implement delete handler")
    let userIndexPath = PhotoViewManager.default.userIndexPath(template: userStartIndexPath, form: indexPath)
    let successBlock: (Bool) -> Void = { [weak self] (success) in
      guard let strongself = self else { return }
      if success {
        let newResource = strongself.resources[resource: indexPath]
        if newResource == resource {
          strongself.removeResourceSuccessfully(at: indexPath)
        } else if let newIndexPath = strongself.resources.allIndexPaths(where: { $0 == resource }, matchFirst: true).first {
          strongself.removeResourceSuccessfully(at: newIndexPath)
        }
      } else {
        resource.removing = false
      }
    }
    tryDeleteResourceHandler?(userIndexPath, successBlock)
  }

  func removeResourceSuccessfully(at indexPath: IndexPath) -> Void {
    var oldFlatList = resources.allIndexPaths(where: { _ in true }, matchFirst: false)
    #if swift(>=4.2)
    let oldFlatIndex = oldFlatList.firstIndex(of: indexPath)
    #else
    let oldFlatIndex = oldFlatList.index(of: indexPath)
    #endif
    _ = deleteResourceHandler?(&resources, indexPath) ?? resources.removeItemAt(indexPath: indexPath)
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

  open override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
    let size = container.preferredContentSize
    self.preferredContentSize = size
    self.currentPhotoViewController?.updateContentViewFrame(size)
    super.preferredContentSizeDidChange(forChildContentContainer: container)
  }

  // MARK: - deinit

  deinit {
    restoreNavigationControllerDelegateHandler?(navigationControllerDelegateStorage)
    PhotoViewManager.default.notificationCenter.removeObserver(self)
  }

}

open class PhotoPage1DController: PhotoPageController<MediaResource> {}

open class PhotoPage2DController: PhotoPageController<[MediaResource]> {}
