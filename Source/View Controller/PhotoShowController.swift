//
//  PhotoViewController.swift
//  PhotoViewController
//
//  Created by Felicity on 8/2/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation
import PhotosUI
import AVFoundation

func upsearch<T, U>(from starter: T, maximumSearch: Int, type: U.Type, father: (T?) -> T?) -> U? {
  var number = 0
  var _nextResponder: T? = starter
  while !(_nextResponder is U), number < maximumSearch {
    _nextResponder = father(_nextResponder)
    number += 1
  }
  return _nextResponder as? U
}

func drawImage(inSize size: CGSize, opaque: Bool = false, scale: CGFloat = 0, action: ((CGContext?) -> Void)) -> UIImage? {
  if #available(iOS 10.0, *) {
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = opaque
    format.scale = scale
    return UIGraphicsImageRenderer(size: size).image { (context) in
      action(context.cgContext)
    }
  } else {
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
    action(UIGraphicsGetCurrentContext())
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
  }
}

extension CGAffineTransform {
  func makeScale(to scale: CGFloat, ratate angle: CGFloat = 0) -> CGAffineTransform {
    let scaleTransform = self.concatenating(CGAffineTransform(scaleX: scale, y: scale))
    let rotateTransform = scaleTransform.concatenating(CGAffineTransform(rotationAngle: angle))
    return rotateTransform
  }
}

extension Comparable {

  func clamp(_ minimum: Self, _ maximum: Self) -> Self {
    return min(max(minimum, self), maximum)
  }

}

open class PhotoShowController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {

  let modally: Bool
  let contentView: UIView
  public let resource: MediaResource
  public let scrollView: UIScrollView
  public let imageView: UIImageView
  @available(iOS 9.1, *)
  public lazy var livePhotoView: PHLivePhotoView = PHLivePhotoView(frame: .zero)
  var isStatusBarHidden: Bool = false

  public init(modally: Bool, resource: MediaResource) {
    self.modally = modally
    self.resource = resource
    self.contentView = UIView(frame: CGRect.zero)
    self.scrollView = UIScrollView(frame: CGRect.zero)
    self.imageView = UIImageView(frame: CGRect.zero)
    super.init(nibName: nil, bundle: nil)
  }

  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override open func viewDidLoad() {
    super.viewDidLoad()
    configScrollView()
    configImageView()
    addImageObserver()
    addImmersionObserver()
    addOrientationObserver()
    configGestureRecognizer()
    loadResource()
    updateImmersingUI()
  }

  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }

  open override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
  }

  public lazy var singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
  public lazy var doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
  public lazy var dismissalGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
  public lazy var pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handleZoomAndRotate))
  public lazy var rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleZoomAndRotate))

  public var dismissalInteractiveController: ZoomOutAnimatedInteractiveController?

  private var embededScrollView: UIScrollView? {
    return upsearch(from: view, maximumSearch: 5, type: UIScrollView.self, father: {
      $0?.superview
    })
  }

  public var dragingDismissalPercentRequired: CGFloat = 0.05
  public var zoomingDismissalPercentRequired: CGFloat = 0.1

  public private(set) var isZoomingAndRotating: Bool = false

  @objc open func handleZoomAndRotate() -> Void {
    guard scrollView.reachMinZoomScale || isZoomingAndRotating else { return }
    let percentComplete: CGFloat = (1 - pinchGestureRecognizer.scale).clamp(0, 1)
    switch (rotationGestureRecognizer.state, pinchGestureRecognizer.state) {
    case (.began, _):
      fallthrough
    case (_, .began):
      isZoomingAndRotating = true
      beginInteractiveDismissalTransition()
    case (.changed, _):
      fallthrough
    case (_, .changed):
      var translation = pinchGestureRecognizer.location(in: pinchGestureRecognizer.view)
      let center = view.center
      translation.x -= center.x
      translation.y -= center.y
      dismissalInteractiveController?.transform = transform(forTranslation: translation)
      changeInteractionProgress(percentComplete)
    case (.ended, _):
      fallthrough
    case (_, .ended):
      finishZoomingAndRotating()
      finishInteractiveTransition(percentComplete > zoomingDismissalPercentRequired)
    case (.cancelled, _):
      fallthrough
    case (_, .cancelled):
      finishZoomingAndRotating()
      finishInteractiveTransition(false)
    default:
      break
    }

  }

  open func finishZoomingAndRotating() -> Void {
    isZoomingAndRotating = false
    pinchGestureRecognizer.scale = 1
    rotationGestureRecognizer.rotation = 0
  }

  @objc open func handlePan(_ pan: UIPanGestureRecognizer) -> Void {
    guard scrollView.reachMinZoomScale else { return }
    let translation = pan.translation(in: pan.view)
    if translation.y <= 0 && dismissalInteractiveController == nil {
      return
    }
    let percentComplete: CGFloat = (translation.y / UIScreen.main.bounds.height).clamp(0, 1)

    switch pan.state {
    case .began:
      beginInteractiveDismissalTransition()
    case .changed:
      dismissalInteractiveController?.transform = transform(forTranslation: translation)
      changeInteractionProgress(percentComplete)
    case .ended:
      pan.setTranslation(.zero, in: pan.view)
      finishInteractiveTransition(percentComplete > dragingDismissalPercentRequired)
    case .cancelled:
      pan.setTranslation(.zero, in: pan.view)
      finishInteractiveTransition(false)
    default:
      break
    }
  }

  public var scalingFator: CGFloat {
    return PhotoViewManager.default.interactiveDismissScaleFactor
  }

  open func transform(forTranslation translation: CGPoint) -> CGAffineTransform {
    if isZoomingAndRotating {
      let scale = pinchGestureRecognizer.scale.clamp(0, 1)
      let angle = rotationGestureRecognizer.rotation
      let scaleTransform = CGAffineTransform.identity.makeScale(to: scale, ratate: angle)
      let moveTransform = scaleTransform.concatenating(CGAffineTransform(translationX: translation.x, y: translation.y))
      return moveTransform
    } else {
      let scale = (1 - translation.y / UIScreen.main.bounds.height * scalingFator).clamp(0, 1)
      let scaleTransform = CGAffineTransform.identity.makeScale(to: scale)
      let moveDownTransform = scaleTransform.concatenating(CGAffineTransform(translationX: translation.x, y: translation.y))
      return moveDownTransform
    }

  }

  open func beginInteractiveDismissalTransition() -> Void {
    guard dismissalInteractiveController == nil else { return }
    scrollView.isUserInteractionEnabled = false
    embededScrollView?.isScrollEnabled = false
    dismissalInteractiveController = ZoomOutAnimatedInteractiveController()
    uniformDismiss()
  }

  open func changeInteractionProgress(_ percentComplete: CGFloat) -> Void {
    dismissalInteractiveController?.update(percentComplete)
    dismissalInteractiveController?.progress = percentComplete
  }

  open func finishInteractiveTransition(_ complete: Bool) -> Void {
    guard dismissalInteractiveController != nil else { return }
    if complete {
      dismissalInteractiveController?.finish()
    } else {
      dismissalInteractiveController?.cancel()
    }
    dismissalInteractiveController?.continueAnimation?()
    dismissalInteractiveController = nil
    embededScrollView?.isScrollEnabled = true
    scrollView.isUserInteractionEnabled = true
  }

  @objc open func handleSingleTap(_ tap: UITapGestureRecognizer) -> Void {
    switch PhotoViewManager.default.viewTapAction {
    case .toggleImmersingState:
      PhotoViewManager.default.nextImmersingState()
    case .dismiss:
      scrollView.zoomToMin(at: .zero)
      uniformDismiss()
    }
  }

  open func uniformDismiss() -> Void {
    navigationController?.setNavigationBarHidden(false, animated: true)
    if modally {
      dismiss(animated: true, completion: nil)
    } else {
      navigationController?.popViewController(animated: true)
    }
  }


  @objc open func handleDoubleTap(_ tap: UITapGestureRecognizer) -> Void {
    let location = tap.location(in: tap.view)
    let insets = scrollView.contentInset
    let offsetLocation = CGRect(origin: location, size: .zero).offsetBy(dx: -insets.left, dy: -insets.top).origin
    toggleZoomLevel(at: offsetLocation)
  }

  open func toggleZoomLevel(at point: CGPoint) -> Void {
    if !scrollView.reachMaxZoomScale {
      scrollView.zoomToMax(at: point)
    } else {
      scrollView.zoomToMin(at: point)
    }
  }

  open func updateImmersingUI(_ state: PhotoImmersingState? = nil) -> Void {
    let isNavigationBarHidden: Bool
    switch state ?? PhotoViewManager.default.immersingState {
    case .normal:
      isStatusBarHidden = false
      isNavigationBarHidden = false
    case .immersed:
      isStatusBarHidden = true
      isNavigationBarHidden = true
    }
    navigationController?.setNavigationBarHidden(isNavigationBarHidden, animated: true)
    setNeedsStatusBarAppearanceUpdate()
  }

  override open var prefersStatusBarHidden: Bool {
    return isStatusBarHidden
  }

  open func configGestureRecognizer() -> Void {
    doubleTapGestureRecognizer.delegate = self
    singleTapGestureRecognizer.delegate = self
    dismissalGestureRecognizer.delegate = self
    pinchGestureRecognizer.delegate = self
    rotationGestureRecognizer.delegate = self

    doubleTapGestureRecognizer.numberOfTapsRequired = 2
    singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
    singleTapGestureRecognizer.require(toFail: dismissalGestureRecognizer)

    view.addGestureRecognizer(doubleTapGestureRecognizer)
    view.addGestureRecognizer(dismissalGestureRecognizer)
    view.addGestureRecognizer(singleTapGestureRecognizer)
    view.addGestureRecognizer(pinchGestureRecognizer)
    view.addGestureRecognizer(rotationGestureRecognizer)

  }

  public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer == dismissalGestureRecognizer {
      let translation =  dismissalGestureRecognizer.translation(in: dismissalGestureRecognizer.view)
      return translation.y > 0
    }
    if gestureRecognizer == rotationGestureRecognizer || gestureRecognizer == pinchGestureRecognizer {
      return scrollView.reachMinZoomScale && pinchGestureRecognizer.scale < 1
    }
    return true
  }

  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer == rotationGestureRecognizer || gestureRecognizer == pinchGestureRecognizer {
      return scrollView.reachMinZoomScale
    }
    if gestureRecognizer == dismissalGestureRecognizer, otherGestureRecognizer.view is UIScrollView {
      if scrollView.contentOffset.y <= 0 {
        return true
      }
    }
    if otherGestureRecognizer.view is UIScrollView {
      return false
    }
    return true
  }

  open var imageViewFrame: CGRect {
    if imageView.image != nil {
      if #available(iOS 11.0, *) {
        return imageView.frame.offsetBy(dx: scrollView.adjustedContentInset.left, dy: scrollView.adjustedContentInset.top)
      } else {
        return imageView.frame.offsetBy(dx: scrollView.contentInset.left, dy: scrollView.contentInset.top)
      }
    } else if let image = PhotoViewManager.default.hintImage {
      if let contentMode = PhotoViewManager.default.contenMode(for: image.size) {
        return destinationResourceContentFrame(contentMode: contentMode, size: image.size).framOnWindow
      }
    }
    return view.bounds
  }

  open func configScrollView() -> Void {
    view.addSubview(contentView)
    contentView.frame = view.bounds
    contentView.addSubview(scrollView)
    scrollView.frame = contentView.bounds
    if #available(iOS 11.0, *) {
      scrollView.contentInsetAdjustmentBehavior = .never
    } else {
      // Fallback on earlier versions
    }
    scrollView.backgroundColor = UIColor.clear
    scrollView.delegate = self
    scrollView.maximumZoomScale = 4
    scrollView.minimumZoomScale = 1
  }

  open var orientationObserver: NSObjectProtocol?

  open func addOrientationObserver() -> Void {
    orientationObserver = NotificationCenter.default.addObserver(forName: UIApplication.didChangeStatusBarOrientationNotification, object: nil, queue: nil, using: { [weak self] _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
        self?.updateContentViewFrame()
      })
    })
  }

  open func updateContentViewFrame() -> Void {
    contentView.frame = view.bounds
    let scale = scrollView.zoomScale
    scrollView.frame = contentView.bounds
    recalibrateImageViewFrame()
    scrollView.setZoomScale(scale, animated: false)
  }


  open func configImageView() -> Void {
    imageView.backgroundColor = UIColor.clear
    imageView.contentMode = .scaleAspectFit
    scrollView.addSubview(imageView)
    imageView.frame = scrollView.bounds

    if #available(iOS 9.1, *) {
      if resource.type ~= .livePhoto {
        livePhotoView.contentMode = .scaleAspectFit
        imageView.addSubview(livePhotoView)
        imageView.isUserInteractionEnabled = true

        let livePhotoBadge = UIImageView(image: PHLivePhotoView.livePhotoBadgeImage(options: [.overContent]))
        imageView.addSubview(livePhotoBadge)
      }
    }
  }

  open func loadResource() -> Void {
    switch resource.type {
    case .image:
      resource.display(inImageView: imageView)
    case .livePhoto:
      if #available(iOS 9.1, *) {
        resource.displayLivePhoto(inLivePhotView: livePhotoView, inImageView: imageView)
      }
    default:
      break
    }
  }

  open func addImageObserver() -> Void {
    switch resource.type {
    case .image:
      imageView.addObserver(self, forKeyPath: #keyPath(UIImageView.image), options: [.new], context: nil)
    case .livePhoto:
      if #available(iOS 9.1, *) {
        livePhotoView.addObserver(self, forKeyPath: #keyPath(PHLivePhotoView.livePhoto), options: [.new], context: nil)
      }
    default:
      break
    }
  }


  open func removeImageObserver() -> Void {
    switch resource.type {
    case .image:
      imageView.removeObserver(self, forKeyPath: #keyPath(UIImageView.image))
    case .livePhoto:
      if #available(iOS 9.1, *) {
        livePhotoView.removeObserver(self, forKeyPath: #keyPath(PHLivePhotoView.livePhoto))
      }
    default:
      break
    }
  }

  open func observeImageSize(forKeyPath keyPath: String?) -> Bool {
    switch resource.type {
    case .image:
      if keyPath == #keyPath(UIImageView.image) {
        return true
      }
    case .livePhoto:
      if keyPath == #keyPath(PHLivePhotoView.livePhoto) {
        return true
      }
    default:
      break
    }
    return false
  }


  open func addImmersionObserver() {
    PhotoViewManager.default.notificationCenter.addObserver(self, selector: #selector(handleImmersionStateDidChangeNotification(_:)), name: NSNotification.Name.PhotoViewControllerImmersionDidChange, object: nil)
  }

  @objc func handleImmersionStateDidChangeNotification(_ note: Notification) -> Void {
    updateImmersingUI()
  }

  open var resourceContentSize: CGSize? {
    switch resource.type {
    case .image:
      if let image = imageView.image {
        return image.size
      }
    case .livePhoto:
      if #available(iOS 9.1, *) {
        if let livePhoto = livePhotoView.livePhoto {
          if livePhoto.size.isValid {
            return livePhoto.size
          }
          if resource.contentSize.isValid {
            return resource.contentSize
          }
        }
      }
    default:
      break
    }
    return nil
  }

  open func recalibrateImageViewFrame() -> Void {
    guard let resourceContentSize = resourceContentSize else { return }
    switch resource.type {
    case .image:
      recalibrateContentViewFrame(resourceSize: resourceContentSize)
    case .livePhoto:
      if #available(iOS 9.1, *) {
        if recalibrateContentViewFrame(resourceSize: resourceContentSize) {
          livePhotoView.frame = imageView.bounds
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let strongself = self else { return }
            strongself.createSnapshotOfResourceView()
          }
        }
      }
    default:
      break
    }
  }

  open func createSnapshotOfResourceView() -> Void {
    guard imageView.image == nil else { return }
    switch resource.type {
    case .livePhoto:
      if #available(iOS 9.1, *) {
        let b = imageView.bounds
        let image = drawImage(inSize: b.size) { _ in
          livePhotoView.drawHierarchy(in: b, afterScreenUpdates: false)
        }
        if let image = image, image.size.isValid {
          imageView.image = image
        }
      }
    default:
      break
    }
  }

  @discardableResult
  open func recalibrateContentViewFrame(resourceSize: CGSize) -> Bool {
    guard resourceSize.isValid else {
      return false
    }
    guard let contentMode = PhotoViewManager.default.contenMode(for: resourceSize) else { return
      false
    }
    let tuple = destinationResourceContentFrame(contentMode: contentMode, size: resourceSize)
    imageView.frame = tuple.framOnScrollView
    scrollView.setZoomScale(1, animated: false)
    updateScrollViewInsets(false)
    return true
  }

  @discardableResult
  open func destinationResourceContentFrame(contentMode: PhotoViewContentMode, size: CGSize) -> (framOnWindow: CGRect, framOnScrollView: CGRect) {
    switch contentMode {
    case .fitScreen:
      return destinationContentFrameToAspectFit(size: size)
    case .fitWidth(let position):
      return destinationContentFrameToFitWidth(size: size, position: position)
    }
  }

  open func destinationContentFrameToAspectFit(size: CGSize) -> (framOnWindow: CGRect, framOnScrollView: CGRect) {
    var _frame = AVMakeRect(aspectRatio: size, insideRect: view.bounds)
    let __frame = _frame
    _frame.origin = .zero
    return (__frame, _frame)
  }

  open func destinationContentFrameToFitWidth(size: CGSize, position: PhotoViewContentPosition) -> (framOnWindow: CGRect, framOnScrollView: CGRect) {
    let bounds = view.bounds
    var _frame = AVMakeRect(aspectRatio: size, insideRect: bounds)
    _frame.origin = .zero
    let scale = bounds.width / _frame.width
    var __frame = _frame.applying(CGAffineTransform(scaleX: scale, y: scale))
    let ___frame = __frame
    switch position {
    case .top:
      __frame.origin = .zero
    case .center:
      __frame.origin = CGPoint(x: 0, y: -(__frame.height - bounds.height) / 2)
    }
    return (__frame, ___frame)
  }

  override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if observeImageSize(forKeyPath: keyPath) {
      recalibrateImageViewFrame()
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  deinit {
    removeImageObserver()
    orientationObserver.map{ NotificationCenter.default.removeObserver($0) }
    PhotoViewManager.default.notificationCenter.removeObserver(self)
  }

  public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageView
  }

  public func scrollViewDidZoom(_ scrollView: UIScrollView) {
    updateScrollViewInsets(true)
  }

  open func updateScrollViewInsets(_ zooming: Bool) -> Void {
    guard let resourceContentSize = resourceContentSize else { return }
    guard let contentMode = PhotoViewManager.default.contenMode(for: resourceContentSize) else { return }
    switch contentMode {
    case .fitScreen:
      let imageViewSize = imageView.frame.size
      let scrollViewSize = scrollView.bounds.size
      let verticalPadding = max((scrollViewSize.height - imageViewSize.height) / 2, 0)
      let horizontalPadding = max((scrollViewSize.width - imageViewSize.width) / 2, 0)
      scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
    case .fitWidth(let position):
      scrollView.contentInset = .zero
      if !zooming, position ~= .center {
        scrollView.setContentOffset(CGPoint(x: 0, y: (scrollView.contentSize.height - scrollView.frame.height) / 2), animated: false)
      }
    }
  }

}
