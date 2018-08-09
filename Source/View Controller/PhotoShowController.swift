//
//  PhotoViewController.swift
//  PhotoViewController
//
//  Created by Felicity on 8/2/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation

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

extension CGAffineTransform {
  func makeScale(to scale: CGFloat, at point: CGPoint, ratate angle: CGFloat = 0) -> CGAffineTransform {
    let moveToOriginTransform = CGAffineTransform(translationX: -point.x, y: -point.y)
    let scaleTransform = moveToOriginTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
    let rotateTransform = scaleTransform.concatenating(CGAffineTransform(rotationAngle: angle))
    let moveBackTransform = rotateTransform.concatenating(CGAffineTransform(translationX: point.x * scale, y: point.y * scale))
    return moveBackTransform
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
  let resource: MediaResource
  let scrollView: UIScrollView
  let imageView: UIImageView
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

  var isZoomingAndRotating: Bool = false

  @objc public func handleZoomAndRotate() -> Void {
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

  func finishZoomingAndRotating() -> Void {
    isZoomingAndRotating = false
    pinchGestureRecognizer.scale = 1
    rotationGestureRecognizer.rotation = 0
  }

  @objc public func handlePan(_ pan: UIPanGestureRecognizer) -> Void {
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

  var scalingFator: CGFloat = 0.9


  func transform(forTranslation translation: CGPoint) -> CGAffineTransform {

    if isZoomingAndRotating {
      let center = CGPoint(x: imageView.bounds.midX, y: imageView.bounds.midY)
      let scale = pinchGestureRecognizer.scale.clamp(0, 1)
      let angle = rotationGestureRecognizer.rotation
      let scaleTransform = CGAffineTransform.identity.makeScale(to: scale, at: center, ratate: angle)
      let moveTransform = scaleTransform.concatenating(CGAffineTransform(translationX: translation.x, y: translation.y))
      return moveTransform
    } else {
      let center = CGPoint(x: imageView.bounds.midX, y: imageView.bounds.midY)
      let scale = (1 - translation.y / UIScreen.main.bounds.height * scalingFator).clamp(0, 1)
      let scaleTransform = CGAffineTransform.identity.makeScale(to: scale, at: center)
      let moveDownTransform = scaleTransform.concatenating(CGAffineTransform(translationX: translation.x, y: translation.y))
      return moveDownTransform
    }

  }

  public func beginInteractiveDismissalTransition() -> Void {
    guard dismissalInteractiveController == nil else { return }
    scrollView.isUserInteractionEnabled = false
    embededScrollView?.isScrollEnabled = false
    dismissalInteractiveController = ZoomOutAnimatedInteractiveController()
    uniformDismiss()
  }

  public func changeInteractionProgress(_ percentComplete: CGFloat) -> Void {
    dismissalInteractiveController?.update(percentComplete)
    dismissalInteractiveController?.progress = percentComplete
  }

  public func finishInteractiveTransition(_ complete: Bool) -> Void {
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

  @objc public func handleSingleTap(_ tap: UITapGestureRecognizer) -> Void {
    switch PhotoViewManager.default.viewTapAction {
    case .toggleImmersingState:
      PhotoViewManager.default.nextImmersingState()
    case .dismiss:
      scrollView.zoomToMin(at: .zero)
      uniformDismiss()
    }
  }

  func uniformDismiss() -> Void {
    navigationController?.setNavigationBarHidden(false, animated: true)
    if modally {
      dismiss(animated: true, completion: nil)
    } else {
      navigationController?.popViewController(animated: true)
    }
  }


  @objc public func handleDoubleTap(_ tap: UITapGestureRecognizer) -> Void {
    let location = tap.location(in: tap.view)
    let insets = scrollView.contentInset
    let offsetLocation = CGRect(origin: location, size: .zero).offsetBy(dx: -insets.left, dy: -insets.top).origin
    toggleZoomLevel(at: offsetLocation)
  }

  public func toggleZoomLevel(at point: CGPoint) -> Void {
    if !scrollView.reachMaxZoomScale {
      scrollView.zoomToMax(at: point)
    } else {
      scrollView.zoomToMin(at: point)
    }
  }

  public func updateImmersingUI(_ state: PhotoImmersingState? = nil) -> Void {
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

  public func configGestureRecognizer() -> Void {
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
    if otherGestureRecognizer.view is UIScrollView {
      return false
    }
    return true
  }

  public var imageViewFrame: CGRect {
    if #available(iOS 11.0, *) {
      return imageView.frame.offsetBy(dx: scrollView.adjustedContentInset.left, dy: scrollView.adjustedContentInset.top)
    } else {
      return imageView.frame.offsetBy(dx: scrollView.contentInset.left, dy: scrollView.contentInset.top)
    }
  }

  public func configScrollView() -> Void {
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

  public var orientationObserver: NSObjectProtocol?

  public func addOrientationObserver() -> Void {
    orientationObserver = NotificationCenter.default.addObserver(forName: UIApplication.didChangeStatusBarOrientationNotification, object: nil, queue: nil, using: { [weak self] _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
        self?.updateContentViewFrame()
      })
    })
  }

  public func updateContentViewFrame() -> Void {
    contentView.frame = view.bounds
    let scale = scrollView.zoomScale
    scrollView.frame = contentView.bounds
    recalibrateImageViewFrame()
    scrollView.setZoomScale(scale, animated: false)
  }


  public func configImageView() -> Void {
    imageView.backgroundColor = UIColor.clear
    imageView.contentMode = .scaleAspectFit
    scrollView.addSubview(imageView)
    imageView.frame = scrollView.bounds
  }

  public func loadResource() -> Void {
    resource.display(inImageView: imageView)
  }

  public func addImageObserver() -> Void {
    imageView.addObserver(self, forKeyPath: #keyPath(UIImageView.image), options: [.new], context: nil)
  }

  public func addImmersionObserver() {
    PhotoViewManager.default.notificationCenter.addObserver(self, selector: #selector(handleImmersionStateDidChangeNotification(_:)), name: NSNotification.Name.PhotoViewControllerImmersionDidChange, object: nil)
  }

  @objc func handleImmersionStateDidChangeNotification(_ note: Notification) -> Void {
    updateImmersingUI()
  }

  public func recalibrateImageViewFrame() -> Void {
    if let image = imageView.image {
      var aframe = AVMakeRect(aspectRatio: image.size, insideRect: view.bounds)
      aframe.origin = .zero
      imageView.frame = aframe
      scrollView.setZoomScale(1, animated: false)
      centerizeImageView()
    }
  }

  override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == #keyPath(UIImageView.image) {
      recalibrateImageViewFrame()
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  deinit {
    navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    imageView.removeObserver(self, forKeyPath: #keyPath(UIImageView.image))
    orientationObserver.map{ NotificationCenter.default.removeObserver($0) }
    PhotoViewManager.default.notificationCenter.removeObserver(self)
  }

  public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageView
  }

  public func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerizeImageView()
  }

  public func centerizeImageView() -> Void {
    let imageViewSize = imageView.frame.size
    let scrollViewSize = scrollView.bounds.size
    let verticalPadding = max((scrollViewSize.height - imageViewSize.height) / 2, 0)
    let horizontalPadding = max((scrollViewSize.width - imageViewSize.width) / 2, 0)
    scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
  }

}
