//
//  Animation.swift
//  PhotoViewController
//
//  Created by Felicity on 8/3/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

public class ZoomInAnimatedTransitioning: ZoomAnimatedTransitioning {

  public override var direction: ZoomAnimatedTransitioningDirection {
    return .incoming
  }

  var fromImageViewFrame: CGRect? {
    return imageViewFrame
  }
  
  var fromImageViewContentMode: ViewContentMode {
    return imageViewContentMode
  }

  public override func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    var aborted: Bool = false
    let containerView = transitionContext.containerView
    defer {
      if aborted {
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        delegate?.transitionDidFinishAnimation(transitionAnimator: self, transitionContext: transitionContext, finished: false)
        provider.currentImageViewHidden = false
      }
    }
    guard let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) else { aborted = true; return }
    guard let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) else { aborted = true; return }
    guard let image = image else { aborted = true; return }
    guard let sourceImageViewFrame = fromImageViewFrame else { aborted = true; return }
    guard let toImageViewFrame = provider.currentImageViewFrame else { aborted = true; return }
    
    provider.currentImageViewHidden = true
    delegate?.transitionWillBegin(transitionAnimator: self, transitionContext: transitionContext)

    // if view isHidden, then its snapshot View is blank
    containerView.addSubview(toVC.view)
    toVC.view.frame = transitionContext.finalFrame(for: toVC)
    // for snapshot without page, autolayout
    toVC.view.setNeedsLayout()
    toVC.view.layoutIfNeeded()
    
    provider.configuration.hintImage = image

    let mockSourceImageView = UIImageView(image: image)
    mockSourceImageView.clipsToBounds = true
    mockSourceImageView.contentMode = fromImageViewContentMode
    mockSourceImageView.frame = sourceImageViewFrame
    delegate?.transitionWillBeginAnimation(transitionAnimator: self, transitionContext: transitionContext, imageView: mockSourceImageView)
    containerView.addSubview(mockSourceImageView)

    let animations: () -> Void = { [weak self, weak transitionContext] in
      mockSourceImageView.frame = toImageViewFrame
      mockSourceImageView.contentMode = .scaleAspectFit
      self?.delegate?.transitionUserAnimation(transitionAnimator: self, transitionContext: transitionContext, isInteractive: transitionContext?.isInteractive ?? false, isCancelled: false, progress: nil, imageView: mockSourceImageView)
    }

    let completion: () -> Void = { [weak self] in
      defer {
        mockSourceImageView.removeFromSuperview()
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
      }
      guard let strongself = self else { return }
      strongself.provider.currentImageViewHidden = false
      strongself.delegate?.transitionDidFinishAnimation(transitionAnimator: strongself, transitionContext: transitionContext, finished: !transitionContext.transitionWasCancelled)
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
    delegate?.transitionDidFinish(transitionAnimator: self, finished: true)
  }

}

