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
  let toImageViewContentMode: UIView.ContentMode
  let provider: ImageZoomProvider
  let animationWillBegin: (() -> Void)?
  let animationDidFinish: ((Bool) -> Void)?
  var imageViewTransformBlock: ((CGAffineTransform) -> Void)?

  /// only valid when option is ImageZoomAnimationOption.fallback
  var deferredCompletion: Bool = false
  public var prepareAnimation: ((_ imageView: UIImageView) -> Void)?
  public var userAnimation: ((_ isInteractive: Bool, _ isCancelled: Bool, _ imageView: UIImageView) -> Void)?

  @available(iOS 10.0, *)
  var animator: UIViewPropertyAnimator? {
    get {
      return animatorInternal as? UIViewPropertyAnimator
    }
    set {
      animatorInternal = newValue
    }
  }

  var animatorInternal: Any?

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
      self.toImageViewFrame = toImageView.superview?.convert(toImageView.frame, to: UIApplication.shared.keyWindow)
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
        return UIViewPropertyAnimator(duration: $0, curve: UIView.AnimationCurve.easeInOut, animations: nil)
      }
    } else {
      option = ImageZoomAnimationOption.fallback(springDampingRatio: 1, initialSpringVelocity: 0, options: [UIView.AnimationOptions.curveEaseIn])
    }
    self.init(duration: duration, option: option, animator: animator, animationWillBegin: animationWillBegin, animationDidFinish: animationDidFinish)
  }

  public var interactiveTransitioning: UIViewControllerInteractiveTransitioning? {
    return provider.dismissalInteractiveController
  }

  var interactiveController: ZoomOutAnimatedInteractiveController? {
    return interactiveTransitioning as? ZoomOutAnimatedInteractiveController
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
        if provider.modally {
          containerSuperview?.addSubview(toVC.view)
        }
      }
    }

    // if view isHidden, then its snapshot View is blank
    containerView.addSubview(toVC.view)
    containerView.addSubview(fromVC.view)


    guard let fromSnapshotView = fromVC.view.snapshotView(afterScreenUpdates: true) else { aborted = true; return }
    guard let toSnapshotView = toVC.view.snapshotView(afterScreenUpdates: true) else { aborted = true; return }

    guard let image = image else { aborted = true; return }
    guard let toImageViewFrame = toImageViewFrame else { aborted = true; return }
    guard let fromImageViewFrame = provider.currentImageViewFrame else { aborted = true; return }

    fromVC.view.isHidden = false
    toVC.view.isHidden = false

    containerView.addSubview(toSnapshotView)
    containerView.addSubview(fromSnapshotView)

    let mockSourceImageView = UIImageView(image: image)
    mockSourceImageView.clipsToBounds = true
    mockSourceImageView.contentMode = .scaleAspectFit
    mockSourceImageView.frame = fromImageViewFrame
    prepareAnimation?(mockSourceImageView)
    containerView.addSubview(mockSourceImageView)

    if let interactiveController = interactiveController {
      interactiveController.addObserver(self, forKeyPath: #keyPath(ZoomOutAnimatedInteractiveController.progress), options: [.new], context: nil)
      interactiveController.addObserver(self, forKeyPath: #keyPath(ZoomOutAnimatedInteractiveController.transform), options: [.new], context: nil)
      interactiveController.observedInteractive = true
    }

    let animtions: (_ interactive: Bool, _ isCancelled: Bool) -> Void = { [weak self] interactive, isCancelled in
      fromSnapshotView.alpha = isCancelled ? 1 : 0
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
        mockSourceImageView.removeFromSuperview()
        toSnapshotView.removeFromSuperview()
        fromSnapshotView.removeFromSuperview()
        // for status bar
        if let strongContext = transitionContext {
          strongContext.completeTransition(!strongContext.transitionWasCancelled)
          PhotoViewManager.default.reloadImmersingState(!strongContext.transitionWasCancelled)
        }
      }
      if let interactiveController = strongself.interactiveController, interactiveController.observedInteractive {
        interactiveController.removeObserver(strongself, forKeyPath: #keyPath(ZoomOutAnimatedInteractiveController.progress))
        interactiveController.removeObserver(strongself, forKeyPath: #keyPath(ZoomOutAnimatedInteractiveController.transform))
      }
      strongself.provider.currentImageViewHidden = false
      strongself.animationDidFinish?(!strongContext.transitionWasCancelled)
      if strongself.provider.modally && !strongContext.transitionWasCancelled {
        containerView?.superview?.addSubview(toVC.view)
      }
    }
    imageViewTransformBlock = { [weak mockSourceImageView] in
      mockSourceImageView?.transform = $0
    }
    if let interactiveController = interactiveController {
      interactiveController.continueAnimation = { [weak self, weak transitionContext, weak interactiveController] in
        guard let strongself = self else { return }
        guard let strongContext = transitionContext else { return }
        let isCancelled = strongContext.transitionWasCancelled
        switch strongself.option {
        case let .fallback(springDampingRatio, initialSpringVelocity, options):
          strongself.deferredCompletion = true
          guard let strongInteractiveController = interactiveController else { return }
          UIView.animate(withDuration: strongself.duration * Double(1 - strongInteractiveController.progress), delay: 0, usingSpringWithDamping: springDampingRatio, initialSpringVelocity: initialSpringVelocity, options: [options, .beginFromCurrentState], animations: {
            animtions(false, isCancelled)
          }, completion: { [weak strongself] (finish) in
            strongself?.deferredCompletion = false
            completion()
          })
        case .perferred:
          if #available(iOS 10.0, *) {
            strongself.animator?.addAnimations {
              animtions(false, isCancelled)
            }
            strongself.animator?.startAnimation()
          }
        }
      }
    }
    switch option {
    case let .fallback(springDampingRatio, initialSpringVelocity, options):
      UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: springDampingRatio, initialSpringVelocity: initialSpringVelocity, options: options, animations: { [weak transitionContext] in
        guard let strongContext = transitionContext else { return }
        animtions(strongContext.isInteractive, strongContext.transitionWasCancelled)
      }) { (finish) in
        completion()
      }
    case .perferred(let block):
      if #available(iOS 10.0, *) {
        animator = block(duration)
        animator?.addAnimations {  [weak transitionContext] in
          guard let strongContext = transitionContext else { return }
          animtions(strongContext.isInteractive, strongContext.transitionWasCancelled)
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

}


@objc public class ZoomOutAnimatedInteractiveController: UIPercentDrivenInteractiveTransition {
  @objc dynamic public var progress: CGFloat = 0
  @objc dynamic public var transform: CGAffineTransform = .identity
  var observedInteractive: Bool = false
  public var continueAnimation: (() -> Void)?
}
