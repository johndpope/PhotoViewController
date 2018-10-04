//
//  ZoomOut.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

public class ZoomOutAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
  let duration: TimeInterval
  let option: ImageZoomAnimationOption
  let image: UIImage?
  var toImageViewFrame: CGRect?
  private var toImageView: UIImageView?
  let toImageViewContentMode: ViewContentMode
  let provider: ImageZoomProvider
  let animationWillBegin: (() -> Void)?
  let animationDidFinish: ((Bool) -> Void)?
  var imageViewTransformBlock: ((CGAffineTransform) -> Void)?

  /// only valid when option is ImageZoomAnimationOption.fallback
  private var deferredCompletion: Bool = false
  public var prepareAnimation: ((_ imageView: UIImageView) -> Void)?
  public var userAnimation: ((_ isInteractive: Bool, _ isCancelled: Bool, _ imageView: UIImageView) -> Void)?
  public var transitionDidFinish: ((Bool) -> Void)?
  private var transitionIsCompleted: Bool = false


  // workaround on @available of stored property
  @available(iOS 10.0, *)
  private var animator: UIViewPropertyAnimator? {
    get {
      return animatorInternal as? UIViewPropertyAnimator
    }
    set {
      animatorInternal = newValue
    }
  }

  private var animatorInternal: Any?

  public init(duration: TimeInterval,
              option: ImageZoomAnimationOption,
              animator: ImageZoomAnimator,
              animationWillBegin: (() -> Void)?,
              animationDidFinish: ((Bool) -> Void)?) {
    self.duration = duration
    self.option = option
    self.animationWillBegin = animationWillBegin
    self.animationDidFinish = animationDidFinish
    switch animator {
    case let .dismissToImageView(toImageView, provider):
      self.image = provider.currentImage
      self.toImageView = toImageView
      self.toImageViewContentMode = toImageView.contentMode
      self.provider = provider
    case let .dismissToImageViewFrame(toImageViewFrame, toImageViewContentMode, provider):
      self.image = provider.currentImage
      self.toImageViewFrame = toImageViewFrame
      self.toImageViewContentMode = toImageViewContentMode
      self.provider = provider
    default:
      fatalError("wrong animator")
    }
  }

  public convenience init(duration: TimeInterval,
                   animator: ImageZoomAnimator,
                   animationWillBegin: (() -> Void)? = nil,
                   animationDidFinish: ((Bool) -> Void)? = nil) {
    let option: ImageZoomAnimationOption
    if #available(iOS 10.0, *) {
      option = ImageZoomAnimationOption.perferred {
        return UIViewPropertyAnimator(duration: $0, curve: ViewAnimationCurve.easeInOut, animations: nil)
      }
    } else {
      option = ImageZoomAnimationOption.fallback(springDampingRatio: 1, initialSpringVelocity: 0, options: [ViewAnimationOptions.curveEaseIn])
    }
    self.init(duration: duration, option: option, animator: animator, animationWillBegin: animationWillBegin, animationDidFinish: animationDidFinish)
  }

  public var interactiveTransitioning: UIViewControllerInteractiveTransitioning? {
    return provider.dismissalInteractiveController
  }

  private var interactiveController: ZoomOutAnimatedInteractiveController? {
    return provider.dismissalInteractiveController
  }

  public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return duration
  }

  public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    var aborted: Bool = false
    let containerView = transitionContext.containerView
    let containerSuperview = containerView.superview
    defer {
      if aborted {
        transitionContext.completeTransition(true)
        animationDidFinish?(false)
        provider.currentImageViewHidden = false
      }
    }
    provider.currentImageViewHidden = true
    animationWillBegin?()

    guard let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) else { aborted = true; return }
    guard let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) else { aborted = true; return }

    defer {
      if aborted {
        if provider.isModalTransition {
          containerSuperview?.addSubview(toVC.view)
        }
      }
    }

    // if view isHidden, then its snapshot View is blank
    containerView.addSubview(toVC.view)
    containerView.addSubview(fromVC.view)

    guard let fromSnapshotView = fromVC.snapshotViewOnlyPageView(afterScreenUpdates: true) else { aborted = true; return }
    guard let toSnapshotView = toVC.view.snapshotView(afterScreenUpdates: true) else { aborted = true; return }

    guard let image = image else { aborted = true; return }
    if let _toImageView = toImageView {
      toImageViewFrame = _toImageView.superview?.convert(_toImageView.frame, to: UIApplication.shared.keyWindow)
      toImageView = nil
    }
    guard let toImageViewFrame = toImageViewFrame else { aborted = true; return }
    guard let fromImageViewFrame = provider.currentImageViewFrame else { aborted = true; return }

    fromVC.view.isHidden = false
    toVC.view.isHidden = false
    toVC.view.frame = transitionContext.finalFrame(for: toVC)

    containerView.addSubview(toSnapshotView)
    toSnapshotView.frame = transitionContext.finalFrame(for: toVC)
    containerView.addSubview(fromSnapshotView)

    let mockSourceImageView = UIImageView(image: image)
    mockSourceImageView.clipsToBounds = true
    mockSourceImageView.contentMode = .scaleAspectFit
    mockSourceImageView.frame = fromImageViewFrame
    prepareAnimation?(mockSourceImageView)
    containerView.addSubview(mockSourceImageView)

    // like a sandwich, top -> bottom: (fromControlSnapshotView, mockSourceImageView, fromSnapshotView)
    let fromControlSnapshotView = fromVC.snapshotViewExceptPageView(afterScreenUpdates: true)
    if let fromControlSnapshotView = fromControlSnapshotView {
      containerView.addSubview(fromControlSnapshotView)
      fromControlSnapshotView.frame = fromSnapshotView.frame
    }

    interactiveController?.addProgressObserver(self)

    let animations: (_ interactive: Bool, _ isCancelled: Bool) -> Void = { [weak self] interactive, isCancelled in
      fromSnapshotView.alpha = isCancelled ? 1 : 0
      fromControlSnapshotView?.alpha = isCancelled ? 1 : 0
      self?.userAnimation?(interactive, isCancelled, mockSourceImageView)
      if !interactive {
        mockSourceImageView.transform = .identity
        mockSourceImageView.frame = isCancelled ? fromImageViewFrame : toImageViewFrame
        guard let strongself = self else { return }
        mockSourceImageView.contentMode = isCancelled ? .scaleAspectFit : strongself.toImageViewContentMode
      }
    }

    let completion: () -> Void = { [weak self, weak transitionContext, weak containerView] in
      guard let strongself = self else { return }
      guard let strongContext = transitionContext else { return }
      if strongContext.transitionWasCancelled && strongself.deferredCompletion {
        return
      }
      defer {
        strongself.transitionIsCompleted = !strongContext.transitionWasCancelled
        toSnapshotView.removeFromSuperview()
        fromSnapshotView.removeFromSuperview()
        mockSourceImageView.removeFromSuperview()
        fromControlSnapshotView?.removeFromSuperview()
        // for status bar
        if let strongContext = transitionContext {
          strongContext.completeTransition(!strongContext.transitionWasCancelled)
          PhotoViewManager.default.reloadImmersiveMode(!strongContext.transitionWasCancelled)
        }
      }
      strongself.provider.currentImageViewHidden = false
      strongself.animationDidFinish?(!strongContext.transitionWasCancelled)
      if strongself.provider.isModalTransition && !strongContext.transitionWasCancelled {
        containerView?.superview?.addSubview(toVC.view)
      }
    }
    imageViewTransformBlock = { [weak mockSourceImageView] in
      mockSourceImageView?.transform = $0
    }
    if let interactiveController = interactiveController {
      interactiveController.continueAnimation = { [weak self, weak transitionContext, weak interactiveController] in
        self?.continueAnimations(using: transitionContext, interactiveController: interactiveController, animations: animations, completion: completion)
      }
    }
    performDefaultAnimation(using: transitionContext, animations: animations, completion: completion)
  }

  func performDefaultAnimation(using transitionContext: UIViewControllerContextTransitioning, animations: @escaping (_ interactive: Bool, _ isCancelled: Bool) -> Void, completion: @escaping() -> Void) -> Void {
    switch option {
    case let .fallback(springDampingRatio, initialSpringVelocity, options):
      UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: springDampingRatio, initialSpringVelocity: initialSpringVelocity, options: options, animations: { [weak transitionContext] in
        guard let strongContext = transitionContext else { return }
        animations(strongContext.isInteractive, strongContext.transitionWasCancelled)
      }) { (finish) in
        completion()
      }
    case .perferred(let block):
      if #available(iOS 10.0, *) {
        animator = block(duration)
        animator?.addAnimations {  [weak transitionContext] in
          guard let strongContext = transitionContext else { return }
          animations(strongContext.isInteractive, strongContext.transitionWasCancelled)
        }
        animator?.addCompletion { (postion) in
          completion()
        }
        animator?.startAnimation()
      } else {
        fatalError("never happen")
      }
    }
  }

  func continueAnimations(using transitionContext: UIViewControllerContextTransitioning?, interactiveController: ZoomOutAnimatedInteractiveController?, animations: @escaping (_ interactive: Bool, _ isCancelled: Bool) -> Void, completion: @escaping() -> Void) -> Void {
    guard let strongContext = transitionContext else { return }
    guard let strongInteractiveController = interactiveController else { return }
    let isCancelled = strongContext.transitionWasCancelled
    switch option {
    case let .fallback(springDampingRatio, initialSpringVelocity, options):
      deferredCompletion = true
      UIView.animate(withDuration: duration * Double(1 - strongInteractiveController.progress), delay: 0, usingSpringWithDamping: springDampingRatio, initialSpringVelocity: initialSpringVelocity, options: [options, .beginFromCurrentState], animations: {
        animations(false, isCancelled)
      }, completion: { [weak self] (finish) in
        self?.deferredCompletion = false
        completion()
      })
    case .perferred:
      if #available(iOS 10.0, *) {
        animator?.stopAnimation(true)
        animator?.addAnimations {
          animations(false, isCancelled)
        }
        animator?.addCompletion { (postion) in
          completion()
        }
        animator?.startAnimation()
      }
    }
  }

  public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == #keyPath(ZoomOutAnimatedInteractiveController.progress) {
      switch option {
      case .perferred:
        if #available(iOS 10.0, *) {
          animator?.pauseAnimation()
          if let interactiveController = interactiveController {
            animator?.fractionComplete = interactiveController.progress
          }
        }
      default:
        break
      }
    } else if keyPath == #keyPath(ZoomOutAnimatedInteractiveController.transform){
      if let change = change, let trans = change[NSKeyValueChangeKey.newKey] as? CGAffineTransform {
        imageViewTransformBlock?(trans)
      }
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  deinit {
    transitionDidFinish?(transitionIsCompleted)
  }

}


@objc public class ZoomOutAnimatedInteractiveController: UIPercentDrivenInteractiveTransition {
  @objc dynamic public var progress: CGFloat = 0
  @objc dynamic public var transform: CGAffineTransform = .identity
  public var continueAnimation: (() -> Void)?
  internal var observerAdded: Bool = false
  internal var removeObserverBlock: (() -> Void)?

  public override func finish() {
    super.finish()
    removeObserverBlock?()
  }

  public override func cancel() {
    super.cancel()
    removeObserverBlock?()
  }

  func addProgressObserver(_ observer: NSObject) {
   addObserver(observer, forKeyPath: #keyPath(ZoomOutAnimatedInteractiveController.progress), options: [.new], context: nil)
   addObserver(observer, forKeyPath: #keyPath(ZoomOutAnimatedInteractiveController.transform), options: [.new], context: nil)
   observerAdded = true
   removeObserverBlock = { [weak self, weak observer] in
      guard let strongObserver = observer else { return }
      guard let strongSelf = self else { return }
      if strongSelf.observerAdded {
        strongSelf.removeObserver(strongObserver, forKeyPath: #keyPath(ZoomOutAnimatedInteractiveController.progress))
        strongSelf.removeObserver(strongObserver, forKeyPath: #keyPath(ZoomOutAnimatedInteractiveController.transform))
        strongSelf.observerAdded = false
        strongSelf.removeObserverBlock = nil
      }
    }
  }
}
