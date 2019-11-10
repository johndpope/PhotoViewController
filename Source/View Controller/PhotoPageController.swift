//
//  PhotoPageController.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

public protocol PhotoPageControllerDelegate: class {
  
  /// delete resource from user's array, required
  func removeUserResource<T>(controller: PhotoPageController<T>, at indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> Void
  
  /// page did scroll
  func pageDidScroll<T>(controller: PhotoPageController<T>, to indexPath: IndexPath) -> Void
  
}

public extension PhotoPageControllerDelegate {
  func removeUserResource<T>(controller: PhotoPageController<T>, at indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> Void {}
  func pageDidScroll<T>(controller: PhotoPageController<T>, to indexPath: IndexPath) -> Void {}
}

open class PhotoPageController<T: ResourceSequence>: UIViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource, LargePhotoViewProvider, ImageZoomForceTouchProvider {

  public let configuration: PhotoViewConfiguration = PhotoViewConfiguration()

  public var isForceTouching: Bool = false {
    didSet {
      let size = configuration.contentSize(forPreviewing: self.isForceTouching, resourceSize: self.currentImageViewFrame?.size)
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

  public var userStartIndexPath: IndexPath = IndexPath(index: -1) {
    didSet {
      let pagingStartIndexPath = configuration.getPageIndexPath(form: userStartIndexPath, desiredLength: T.indexPathLength)
      assert(!pagingStartIndexPath.isEmpty, "You must set resource array before setting any index")
      self.pagingStartIndexPath = pagingStartIndexPath
    }
  }
  
  /// the length is equal to array's level
  public private(set) var pagingStartIndexPath: IndexPath = IndexPath(index: -1)

  /// the length is not equal to array's level, usually from user UI
  public var userCurrentIndexPath: IndexPath {
    return configuration.getUserIndexPath(template: userStartIndexPath, form: pagingCurrentIndexPath)
  }

  public private(set) var pagingCurrentIndexPath: IndexPath = IndexPath(index: -1) {
    didSet {
      delegate?.pageDidScroll(controller: self, to: userCurrentIndexPath)
    }
  }

  open var isStatusBarHidden: Bool = false {
    didSet {
      setNeedsStatusBarAppearanceUpdate()
    }
  }

  public weak var delegate: PhotoPageControllerDelegate?

  public private(set) var navigationOrientation: PageViewControllerNavigationOrientation = .horizontal

  public private(set) var interPageSpacing: Double = 0

  open var loop: Bool = true
    
  open var sequence: T!

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

  public private(set) lazy var pageController = UIPageViewController(transitionStyle: PageViewControllerTransitionStyle.scroll, navigationOrientation: navigationOrientation, options: [interPageSpacingKey: NSNumber(value: interPageSpacing)])

  // MARK: - init

  public convenience init(isModalTransition: Bool, navigationOrientation: PageViewControllerNavigationOrientation = .horizontal, interPageSpacing: Double = 10) {
    self.init(nibName: nil, bundle: nil)
    self.modalPresentationCapturesStatusBarAppearance = true
    self.isModalTransition = isModalTransition
    self.navigationOrientation = navigationOrientation
    self.interPageSpacing = interPageSpacing
  }

  // MARK: - viewDidLoad

  override open func viewDidLoad() {
    super.viewDidLoad()
    addPage()
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
    pageController.setViewControllers([photoShow(modally: isModalTransition, resource: sequence[page])], direction: forward ? .forward : .reverse, animated: animated, completion: nil)
  }

  // MARK: - single photo

  open func photoShow(modally isModalTransition: Bool, resource: MediaResource) -> UIViewController {
    return PhotoShowController(isModalTransition: isModalTransition, resource: resource, configuration: configuration)
  }

  // MARK: - get index

  open func indexPathFor(_ viewController: UIViewController) -> IndexPath? {
    guard let viewController = viewController as? PhotoShowController else { return nil }
    return sequence.filter(where: { $0 == viewController.resource }).first
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
    guard sequence.filter(where: { _ in true }).contains(indexPath) else {
      return
    }
    guard let delegate = delegate else { return }
    let resource = sequence[indexPath]
    guard !resource.removing else {
      return
    }
    resource.removing = true
    let userIndexPath = configuration.getUserIndexPath(template: userStartIndexPath, form: indexPath)
    let completion: (Bool) -> Void = { [weak self] (success) in
      guard let strongself = self else { return }
      if success {
        let newResource = strongself.sequence[indexPath]
        if newResource == resource {
          strongself.removeResourceSuccessfully(at: indexPath)
        } else if let newIndexPath = strongself.sequence.filter(where: { $0 == resource }).first {
          strongself.removeResourceSuccessfully(at: newIndexPath)
        }
      } else {
        resource.removing = false
      }
    }
    delegate.removeUserResource(controller: self, at: userIndexPath, completion: completion)
  }

  open func removeResourceSuccessfully(at indexPath: IndexPath) -> Void {
    var oldFlatList = sequence.filter(where: { _ in true })
    #if swift(>=4.2)
    let oldFlatIndex = oldFlatList.firstIndex(of: indexPath)
    #else
    let oldFlatIndex = oldFlatList.index(of: indexPath)
    #endif
    _ = sequence.remove(at: indexPath)
    var newFlatList = sequence.filter(where: { _ in true })
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


  open func removeCurrentResource() {
    removeResource(at: pagingCurrentIndexPath)
  }


  // MARK: - UIPageViewControllerDataSource

  open func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
    guard let indexPath = indexPathFor(viewController) else { return nil }
    guard let previousIndexPath = sequence.indexPath(before: indexPath, loop: loop) else { return nil }
    debuglog("moving to page \(previousIndexPath)")
    return photoShow(modally: isModalTransition, resource: sequence[previousIndexPath])
  }

  open func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
    guard let indexPath = indexPathFor(viewController) else { return nil }
    guard let nextIndexPath = sequence.indexPath(after: indexPath, loop: loop) else { return nil }
    debuglog("moving to page \(nextIndexPath)")
    return photoShow(modally: isModalTransition, resource: sequence[nextIndexPath])
  }

  // MARK: - UIPageViewControllerDelegate

  open func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
    if let viewController = currentPhotoViewController, let indexPath = indexPathFor(viewController) {
      pagingCurrentIndexPath = indexPath
    }
  }

  open func pageViewControllerSupportedInterfaceOrientations(_ pageViewController: UIPageViewController) -> UIInterfaceOrientationMask {
    return currentPhotoViewController?.supportedInterfaceOrientations ?? supportedInterfaceOrientations
  }

  open func pageViewControllerPreferredInterfaceOrientationForPresentation(_ pageViewController: UIPageViewController) -> UIInterfaceOrientation {
    return currentPhotoViewController?.preferredInterfaceOrientationForPresentation ?? preferredInterfaceOrientationForPresentation
  }

  // MARK: - UIViewController
  open override var prefersStatusBarHidden: Bool {
    return isStatusBarHidden
  }

  open override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
    let size = container.preferredContentSize
    self.preferredContentSize = size
    self.currentPhotoViewController?.updateContentViewFrame(size)
    super.preferredContentSizeDidChange(forChildContentContainer: container)
  }

  // MARK: - deinit

  deinit {
    configuration.notificationCenter.removeObserver(self)
  }

}

open class PhotoPageSingleController: PhotoPageController<MediaResource> {}

open class PhotoPage1DController: PhotoPageController<[MediaResource]> {}

open class PhotoPage2DController: PhotoPageController<[[MediaResource]]> {}
