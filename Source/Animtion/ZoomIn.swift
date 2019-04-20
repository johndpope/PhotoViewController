//
//  Animation.swift
//  PhotoViewController
//
//  Created by Felicity on 8/3/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

public class ZoomInAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {

  let duration: TimeInterval
  let option: ImageZoomAnimationOption
  let image: UIImage?
  let fromImageViewFrame: CGRect?
  let fromImageViewContentMode: ViewContentMode
  let provider: LargePhotoViewProvider
  let animationWillBegin: (() -> Void)?
  let animationDidFinish: ((Bool) -> Void)?

  public var prepareAnimation: ((_ imageView: UIImageView) -> Void)?
  public var userAnimation: ((_ isInteractive: Bool, _ imageView: UIImageView) -> Void)?
  public var transitionDidFinish: (() -> Void)?

  public init(duration: TimeInterval,
              option: ImageZoomAnimationOption,
              provider: PhotoZoomInProvider,
              animationWillBegin: (() -> Void)?,
              animationDidFinish: ((Bool) -> Void)?) {
    self.duration = duration
    self.option = option
    self.animationWillBegin = animationWillBegin
    self.animationDidFinish = animationDidFinish
    self.image = provider.source.image
    self.fromImageViewFrame = provider.source.frame
    self.fromImageViewContentMode = provider.source.contentMode
    self.provider = provider.destionation
  }

  public convenience init(duration: TimeInterval,
                          provider: PhotoZoomInProvider,
                          animationWillBegin: (() -> Void)? = nil,
                          animationDidFinish: ((Bool) -> Void)? = nil) {
    let option: ImageZoomAnimationOption
    if #available(iOS 10.0, *) {
      option = ImageZoomAnimationOption.perferred {
        return UIViewPropertyAnimator(duration: $0, dampingRatio: 0.6, animations: nil)
      }
    } else {
      option = ImageZoomAnimationOption.fallback(springDampingRatio: 1, initialSpringVelocity: 0, options: [ViewAnimationOptions.curveEaseInOut])
    }
    self.init(duration: duration, option: option, provider: provider, animationWillBegin: animationWillBegin, animationDidFinish: animationDidFinish)
  }

  public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return duration
  }

  public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    var aborted: Bool = false
    defer {
      if aborted {
        transitionContext.completeTransition(true)
        animationDidFinish?(false)
        provider.currentImageViewHidden = false
      }
    }
    provider.currentImageViewHidden = true
    animationWillBegin?()
    let containerView = transitionContext.containerView
    guard let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) else { aborted = true; return }
    guard let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) else { aborted = true; return }


    // if view isHidden, then its snapshot View is blank
    containerView.addSubview(toVC.view)
    containerView.addSubview(fromVC.view)
    toVC.view.frame = transitionContext.finalFrame(for: toVC)
    // for snapshot without page, autolayout
    toVC.view.setNeedsLayout()
    toVC.view.layoutIfNeeded()

    guard let fromSnapshotView = fromVC.view.snapshotView(afterScreenUpdates: true) else { aborted = true; return }

    guard let toSnapshotView = toVC.snapshotViewOnlyPageView(afterScreenUpdates: true) else { aborted = true; return }

    guard let image = image else { aborted = true; return }
    PhotoViewManager.default.hintImage = image
    guard let sourceImageViewFrame = fromImageViewFrame else { aborted = true; return }
    guard let toImageViewFrame = provider.currentImageViewFrame else { aborted = true; return }


    fromVC.view.isHidden = false
    toVC.view.isHidden = false
    toSnapshotView.alpha = 0
    toSnapshotView.frame = transitionContext.finalFrame(for: toVC)

    containerView.addSubview(toSnapshotView)
    containerView.addSubview(fromSnapshotView)

    let mockSourceImageView = UIImageView(image: image)
    mockSourceImageView.clipsToBounds = true
    mockSourceImageView.contentMode = fromImageViewContentMode
    mockSourceImageView.frame = sourceImageViewFrame
    prepareAnimation?(mockSourceImageView)
    containerView.addSubview(mockSourceImageView)

    // like a sandwich, top -> bottom: (toControlSnapshotView, mockSourceImageView, toSnapshotView)
    let toControlSnapshotView = toVC.snapshotViewExceptPageView(afterScreenUpdates: true)
    if let toControlSnapshotView = toControlSnapshotView {
      containerView.addSubview(toControlSnapshotView)
      toControlSnapshotView.alpha = 0
      toControlSnapshotView.frame = toSnapshotView.frame
    }

    let animations: () -> Void = { [weak self] in
      toSnapshotView.alpha = 1
      toControlSnapshotView?.alpha = 1
      fromSnapshotView.alpha = 0
      mockSourceImageView.frame = toImageViewFrame
      mockSourceImageView.contentMode = .scaleAspectFit
      self?.userAnimation?(transitionContext.isInteractive, mockSourceImageView)
    }

    let completion: () -> Void = { [weak self] in
      defer {
        fromSnapshotView.removeFromSuperview()
        toSnapshotView.removeFromSuperview()
        mockSourceImageView.removeFromSuperview()
        toControlSnapshotView?.removeFromSuperview()
        toVC.view.isHidden = false
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
      }
      guard let strongself = self else { return }
      strongself.provider.currentImageViewHidden = false
      strongself.animationDidFinish?(!transitionContext.transitionWasCancelled)
    }
    performDefaultAnimations(animations, completion: completion)
  }

  func performDefaultAnimations(_ animations: @escaping () -> Void, completion: @escaping() -> Void) -> Void {
    switch option {
    case let .fallback(springDampingRatio, initialSpringVelocity, options):
      UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: springDampingRatio, initialSpringVelocity: initialSpringVelocity, options: options, animations: {
        animations()
      }) { (finish) in
        completion()
      }
    case .perferred(let block):
      if #available(iOS 10.0, *) {
        let animator = block(duration)
        animator.addAnimations {
          animations()
        }
        animator.addCompletion { (postion) in
          completion()
        }
        animator.startAnimation()
      } else {
        fatalError()
      }
    }
  }

  deinit {
    transitionDidFinish?()
  }

}

