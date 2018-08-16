//
//  PhotoViewController.swift
//  PhotoViewController
//
//  Created by Felicity on 8/2/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation
import PhotosUI
import AVFoundation.AVUtilities

#if swift(>=4.2)
typealias GestureRecognizerState = UIGestureRecognizer.State
#else
typealias GestureRecognizerState = UIGestureRecognizerState
#endif

// somehow I cannot log state directly
extension GestureRecognizerState {
  var name: String {
    switch self {
    case .began:
      return "began"
    case .possible:
      return "possible"
    case .changed:
      return "changed"
    case .ended:
      return "ended"
    case .cancelled:
      return "cancelled"
    case .failed:
      return "failed"
    }
  }
}

func upsearch<T, U>(from starter: T, maximumSearch: Int, type: U.Type, father: (T?) -> T?) -> U? {
  var number = 0
  var _nextFinder: T? = starter
  while !(_nextFinder is U), number < maximumSearch {
    _nextFinder = father(_nextFinder)
    number += 1
  }
  return _nextFinder as? U
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

  public var isForceTouching: Bool = false {
    didSet {
      forceTouchDidChange()
    }
  }
  public let isModalTransition : Bool
  public let contentView: UIView
  public private(set) var isStatusBarHidden: Bool = false {
    didSet {
      setNeedsStatusBarAppearanceUpdate()
    }
  }

  public let resource: MediaResource
  public let scrollView: UIScrollView
  public let imageView: UIImageView
  @available(iOS 9.1, *)
  public lazy var livePhotoView: PHLivePhotoView = PHLivePhotoView(frame: .zero)

  public var dismissalInteractiveController: ZoomOutAnimatedInteractiveController?

  public var dragingDismissalPercentRequired: CGFloat = 0.05
  public var zoomingDismissalPercentRequired: CGFloat = 0.1

  public private(set) var isZoomingAndRotating: Bool = false

  public var embededScrollView: UIScrollView? {

    return upsearch(from: view, maximumSearch: 5, type: UIScrollView.self, father: {
      $0?.superview
    })
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
    case .gif:
      return gifResourceContentSize
    case .unspecified:
      return otherResourceContentSize
    }
    return nil
  }

  open var scalingFator: CGFloat {
    return PhotoViewManager.default.interactiveDismissScaleFactor
  }

  open var orientationObserver: NSObjectProtocol?

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

  // MARK: - gesture recognizers

  public lazy var singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
  public lazy var doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
  public lazy var dismissalGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
  public lazy var pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handleZoomAndRotate))
  public lazy var rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleZoomAndRotate))

  // MARK: - init method

  public init(isModalTransition: Bool, resource: MediaResource) {
    self.isModalTransition  = isModalTransition
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
    addImmersiveModeObserver()
    addOrientationObserver()
    configGestureRecognizer()
    loadResource()
    updateImmersiveUI()
  }

  // MARK: - initial setup

  open func configScrollView() -> Void {
    view.addSubview(contentView)
    contentView.frame = view.bounds
    contentView.addSubview(scrollView)
    scrollView.frame = contentView.bounds
    if #available(iOS 11.0, *) {
      scrollView.contentInsetAdjustmentBehavior = .never
    } else {
      automaticallyAdjustsScrollViewInsets = false
      // Fallback on earlier versions
    }

    scrollView.backgroundColor = UIColor.clear
    scrollView.delegate = self
    scrollView.maximumZoomScale = 4
    scrollView.minimumZoomScale = 1
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
    switch resource.type {
    case .image:
      break
    case .livePhoto:
      break
    case .gif:
      configGIFGestureRecognizer()
    case .unspecified:
      configOtherGestureRecognizer()
    }

    view.addGestureRecognizer(doubleTapGestureRecognizer)
    view.addGestureRecognizer(dismissalGestureRecognizer)
    view.addGestureRecognizer(singleTapGestureRecognizer)
    view.addGestureRecognizer(pinchGestureRecognizer)
    view.addGestureRecognizer(rotationGestureRecognizer)

  }

  open func configImageView() -> Void {
    imageView.backgroundColor = UIColor.clear
    imageView.contentMode = .scaleAspectFit
    scrollView.addSubview(imageView)
    imageView.frame = scrollView.bounds

    switch resource.type {
    case .image:
      break
    case .livePhoto:
      if #available(iOS 9.1, *) {
        livePhotoView.contentMode = .scaleAspectFit
        imageView.addSubview(livePhotoView)
        imageView.isUserInteractionEnabled = true
        let livePhotoBadge = UIImageView(image: PHLivePhotoView.livePhotoBadgeImage(options: [.overContent]))
        imageView.addSubview(livePhotoBadge)
      }
    case .gif:
      configGIFImageView()
    case .unspecified:
      configGIFImageView()
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
    case .gif:
      loadGIFResource()
    case .unspecified:
      loadOtherResource()
    }
  }

  // MARK: - zooming dismissal method

  open func finishZoomingAndRotating(_ completed: Bool) -> Void {
    guard isZoomingAndRotating else { return }
    debuglog(#function)
    isZoomingAndRotating = false
    pinchGestureRecognizer.scale = 1
    rotationGestureRecognizer.rotation = 0
  }

  // MARK: - dismissal transform


  open func transform(forTranslation translation: CGPoint) -> CGAffineTransform {
    if isZoomingAndRotating {
      let scale = pinchGestureRecognizer.scale.clamp(0, CGFloat.greatestFiniteMagnitude)
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

  // MARK: - dismissal

  open func uniformDismiss() -> Void {
    if isModalTransition  {
      dismiss(animated: true, completion: nil)
    } else {
      updateImmersiveUI(.normal)
      navigationController?.popViewController(animated: true)
    }
  }

  // MARK: - interactive dismissal

  open func beginInteractiveDismissalTransition() -> Void {
    guard dismissalInteractiveController == nil else { return }
    debuglog(#function)
    scrollView.isUserInteractionEnabled = false
    scrollView.pinchGestureRecognizer?.isEnabled = false
    embededScrollView?.isScrollEnabled = false
    dismissalInteractiveController = ZoomOutAnimatedInteractiveController()
    uniformDismiss()
  }

  open func changeInteractionProgress(_ percentComplete: CGFloat) -> Void {
    debuglog(#function)
    dismissalInteractiveController?.update(percentComplete)
    dismissalInteractiveController?.progress = percentComplete
  }

  open func finishInteractiveTransition(_ complete: Bool) -> Void {
    guard dismissalInteractiveController != nil else { return }
    debuglog(#function)
    if complete {
      dismissalInteractiveController?.finish()
    } else {
      dismissalInteractiveController?.cancel()
    }
    dismissalInteractiveController?.continueAnimation?()
    dismissalInteractiveController = nil
    embededScrollView?.isScrollEnabled = true
    scrollView.pinchGestureRecognizer?.isEnabled = true
    scrollView.isUserInteractionEnabled = true
  }

  // MARK: - gesture handler


  @objc open func handleSingleTap(_ tap: UITapGestureRecognizer) -> Void {
    debuglog("Tap(single) state: \(tap.state.name)")
    switch PhotoViewManager.default.viewTapAction {
    case .toggleImmersiveMode:
      PhotoViewManager.default.nextImmersiveMode()
    case .dismiss:
      scrollView.zoomToMin(at: .zero)
      uniformDismiss()
    }
  }

  @objc open func handleDoubleTap(_ tap: UITapGestureRecognizer) -> Void {
    debuglog("Tap(double) state: \(tap.state.name)")
    let location = tap.location(in: tap.view)
    let insets = scrollView.contentInset
    let offsetLocation = CGRect(origin: location, size: .zero).offsetBy(dx: -insets.left, dy: -insets.top).origin
    toggleZoomLevel(at: offsetLocation)
  }

  @objc open func handlePan(_ pan: UIPanGestureRecognizer) -> Void {
    if isZoomingAndRotating {
      debuglog("is zooming")
      return
    }
    debuglog("Pan state: \(pan.state.name)")
    guard scrollView.reachMinZoomScale else { return }
    let translation = pan.translation(in: pan.view)
    if translation.y < 0 && dismissalInteractiveController == nil {
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

  @objc open func handleZoomAndRotate() -> Void {
    guard scrollView.reachMinZoomScale || isZoomingAndRotating else { return }
    if !isZoomingAndRotating && dismissalInteractiveController != nil {
      debuglog("is draging")
      return
    }
    debuglog("Pinch state: \(pinchGestureRecognizer.state.name), Rotation state: \(rotationGestureRecognizer.state.name)")
    let percentComplete: CGFloat = (1 - pinchGestureRecognizer.scale).clamp(0, 1)
    switch (rotationGestureRecognizer.state, pinchGestureRecognizer.state) {
    case (.began, _):
      fallthrough
    case (_, .began):
      if isZoomingAndRotating {
        scrollView.zoomToMin(at: .zero, false)
      }
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
      let completed = percentComplete > zoomingDismissalPercentRequired
      finishInteractiveTransition(completed)
      finishZoomingAndRotating(completed)
    case (.cancelled, _):
      fallthrough
    case (_, .cancelled):
      finishInteractiveTransition(false)
      finishZoomingAndRotating(false)
    default:
      break
    }

  }

  // MARK: - zooming

  open func toggleZoomLevel(at point: CGPoint) -> Void {
    if !scrollView.reachMaxZoomScale {
      scrollView.zoomToMax(at: point)
    } else {
      scrollView.zoomToMin(at: point)
    }
  }

  // MARK: - ImmersiveUI

  open func updateImmersiveUI(_ state: PhotoImmersiveMode? = nil) -> Void {
    debuglog(#function)
    let isNavigationBarHidden: Bool
    switch state ?? PhotoViewManager.default.immersiveMode {
    case .normal:
      isStatusBarHidden = false
      isNavigationBarHidden = false
    case .immersive:
      isStatusBarHidden = true
      isNavigationBarHidden = true
    }
    navigationController?.setNavigationBarHidden(isNavigationBarHidden, animated: true)
  }

  // MARK: - UIGestureRecognizerDelegate

  public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer == singleTapGestureRecognizer {
      if #available(iOS 9.1, *) {
        if resource.type ~= .livePhoto {
          let state = livePhotoView.playbackGestureRecognizer.state
          debuglog("Live Photo Playback Gesture: \(state.name)")
          return state ~= .possible
        }
      }
    }
    if gestureRecognizer == dismissalGestureRecognizer {
      let translation =  dismissalGestureRecognizer.translation(in: dismissalGestureRecognizer.view)
      return translation.y > 0 && !isZoomingAndRotating
    }
    if gestureRecognizer == rotationGestureRecognizer || gestureRecognizer == pinchGestureRecognizer {
      if !isZoomingAndRotating && dismissalInteractiveController != nil {
        return false
      }
      return scrollView.reachMinZoomScale && pinchGestureRecognizer.scale < 1
    }
    return true
  }

  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer == rotationGestureRecognizer || gestureRecognizer == pinchGestureRecognizer {
      return scrollView.reachMinZoomScale
    }
    if gestureRecognizer == dismissalGestureRecognizer, otherGestureRecognizer.view is UIScrollView {
      // for contentMode = .fitWidth
      if scrollView.contentOffset.y <= 0 {
        return true
      }
    }
    if otherGestureRecognizer.view is UIScrollView {
      return false
    }
    return true
  }


  // MARK: - Orientation
  #if swift(>=4.2)
  let didChangeStatusBarOrientationNotificationName: NSNotification.Name = UIApplication.didChangeStatusBarOrientationNotification
  #else
  let didChangeStatusBarOrientationNotificationName: NSNotification.Name = NSNotification.Name.UIApplicationDidChangeStatusBarOrientation
  #endif

  open func addOrientationObserver() -> Void {
    orientationObserver = NotificationCenter.default.addObserver(forName: didChangeStatusBarOrientationNotificationName, object: nil, queue: nil, using: { [weak self] _ in
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

  // MARK: - resource content size observer


  open func addImageObserver() -> Void {
    switch resource.type {
    case .image:
      imageView.addObserver(self, forKeyPath: #keyPath(UIImageView.image), options: [.new], context: nil)
    case .livePhoto:
      if #available(iOS 9.1, *) {
        livePhotoView.addObserver(self, forKeyPath: #keyPath(PHLivePhotoView.livePhoto), options: [.new], context: nil)
      }
    case .gif:
      addGIFImageObserver()
    case .unspecified:
      addOtherImageObserver()
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
    case .gif:
      removeGIFImageObserver()
    case .unspecified:
      removeOtherImageObserver()
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
    case .gif:
      return observeGIFImageSize(forKeyPath: keyPath)
    case .unspecified:
      return observeOtherImageSize(forKeyPath: keyPath)
    }
    return false
  }

  // MARK: - ImmersiveMode observer

  open func addImmersiveModeObserver() {
    PhotoViewManager.default.notificationCenter.addObserver(self, selector: #selector(handleImmersiveModeDidChangeNotification(_:)), name: NSNotification.Name.PhotoViewControllerImmersiveModeDidChange, object: nil)
  }

  @objc func handleImmersiveModeDidChangeNotification(_ note: Notification) -> Void {
    updateImmersiveUI()
  }

  // MARK: - snapshot view

  open func createSnapshotOfResourceView() -> Void {
    guard imageView.image == nil else { return }
    switch resource.type {
    case .image:
      break
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
    case .gif:
      createGIFSnapshotOfResourceView()
    case .unspecified:
      createOtherSnapshotOfResourceView()
    }
  }

  // MARK: - resource content frame

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
    case .gif:
      recalibrateGIFImageViewFrame()
    case .unspecified:
      recalibrateOtherImageViewFrame()
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

  // MARK: - centerize content if needed

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
        scrollView.scrollRectToVisible(AVMakeRect(aspectRatio: view.bounds.size, insideRect: imageView.frame), animated: false)
      }
    }
  }


  // MARK: - subclass method

  open var gifResourceContentSize: CGSize? { subclassMustImplement(); return nil }

  open var otherResourceContentSize: CGSize? { subclassMustImplement(); return nil }

  open func loadGIFResource() -> Void { subclassMustImplement() }

  open func loadOtherResource() -> Void { subclassMustImplement() }

  open func addGIFImageObserver() -> Void { subclassMustImplement() }

  open func addOtherImageObserver() -> Void { subclassMustImplement() }

  open func removeGIFImageObserver() -> Void { subclassMustImplement() }

  open func removeOtherImageObserver() -> Void { subclassMustImplement() }

  open func observeGIFImageSize(forKeyPath keyPath: String?) -> Bool { subclassMustImplement(); return false }

  open func observeOtherImageSize(forKeyPath keyPath: String?) -> Bool { subclassMustImplement(); return false }

  open func configGIFGestureRecognizer() -> Void {}

  open func configOtherGestureRecognizer() -> Void {}

  open func createGIFSnapshotOfResourceView() -> Void {}

  open func createOtherSnapshotOfResourceView() -> Void {}

  open func configGIFImageView() -> Void { subclassMustImplement() }

  open func configOtherImageView() -> Void { subclassMustImplement() }

  open func recalibrateGIFImageViewFrame() -> Void { subclassMustImplement() }

  open func recalibrateOtherImageViewFrame() -> Void { subclassMustImplement() }

  open func subclassMustImplement(_ method: String = #function) -> Void {
    fatalError("subclass must implement \(method)")
  }


  // MARK: - 3d touch

  open func forceTouchDidChange() -> Void {
    if #available(iOS 9.1, *) {
      if resource.type ~= .livePhoto {
        if isForceTouching {
          startPlayingLivePhoto()
        } else {
          livePhotoView.stopPlayback()
        }
      }
    }
  }

  @available(iOS 9.1, *)
  open func startPlayingLivePhoto() -> Void {
    livePhotoView.startPlayback(with: .full)
  }

  // MARK: - UIScrollViewDelegate

  public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageView
  }

  public func scrollViewDidZoom(_ scrollView: UIScrollView) {
    updateScrollViewInsets(true)
  }

  // MARK: - UIViewController

  override open var prefersStatusBarHidden: Bool {
    return isStatusBarHidden
  }

  open func imageDidChange() -> Void {
    recalibrateImageViewFrame()
    if #available(iOS 9.1, *) {
      if resource.type ~= .livePhoto {
        if isForceTouching {
          startPlayingLivePhoto()
        }
      }
    }
  }

  // MARK: - KVO

  override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if observeImageSize(forKeyPath: keyPath) {
      imageDidChange()
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  // MARK: - deinit

  deinit {
    removeImageObserver()
    orientationObserver.map{ NotificationCenter.default.removeObserver($0) }
    PhotoViewManager.default.notificationCenter.removeObserver(self)
  }


}
