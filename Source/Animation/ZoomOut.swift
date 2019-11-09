//
//  ZoomOut.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

public class ZoomOutAnimatedTransitioning: ZoomAnimatedTransitioning {

  public weak var transferrer: UINavigationControllerDelegateTransferrer?

  public override var direction: ZoomAnimatedTransitioningDirection {
    return .outgoing
  }

  private var toImageViewFrame: CGRect? {
    return imageViewFrame
  }

  private var toImageViewContentMode: ViewContentMode {
    return imageViewContentMode
  }

  private var interactiveImageViewTransformBlock: ((CGAffineTransform) -> Void)?

  private var interactivePercentAnimationsBlock: ((CGFloat) -> Void)?

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

  public var interactiveTransitioning: UIViewControllerInteractiveTransitioning? {
    return provider.dismissalInteractiveController
  }

  private var interactiveController: ZoomOutAnimatedInteractiveController? {
    return provider.dismissalInteractiveController
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

    guard let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) else { aborted = true; return }
    guard let image = image else { aborted = true; return }
    guard let toImageViewFrame = toImageViewFrame else { aborted = true; return }
    guard let fromImageViewFrame = provider.currentImageViewFrame else { aborted = true; return }
    
    provider.currentImageViewHidden = true
    delegate?.transitionWillBegin(transitionAnimator: self, transitionContext: transitionContext)

    let previousToViewSuperview = toVC.view.superview
    if previousToViewSuperview == nil {
      containerView.insertSubview(toVC.view, at: 0)
      toVC.view.frame = transitionContext.finalFrame(for: toVC)      
    }

    let mockSourceImageView = UIImageView(image: image)
    mockSourceImageView.clipsToBounds = true
    mockSourceImageView.contentMode = .scaleAspectFit
    mockSourceImageView.frame = fromImageViewFrame
    delegate?.transitionWillBeginAnimation(transitionAnimator: self, transitionContext: transitionContext, imageView: mockSourceImageView)
    containerView.addSubview(mockSourceImageView)

    interactiveController?.addProgressObserver(self)

    let animations: (_ interactive: Bool, _ isCancelled: Bool, _ expectedEndingProgress: CGFloat) -> Void = { [weak self, weak transitionContext] interactive, isCancelled, expectedEndingProgress in
      self?.delegate?.transitionUserAnimation(transitionAnimator: self, transitionContext: transitionContext, isInteractive: interactive, isCancelled: isCancelled, progress: (interactive ? expectedEndingProgress : CGFloat(isCancelled ? 0 : 1)), imageView: mockSourceImageView)
      if !interactive {
        mockSourceImageView.transform = .identity
        mockSourceImageView.frame = isCancelled ? fromImageViewFrame : toImageViewFrame
        guard let strongself = self else { return }
        mockSourceImageView.contentMode = isCancelled ? .scaleAspectFit : strongself.toImageViewContentMode
      }
    }

    let completion: () -> Void = { [weak self, weak transitionContext] in
      guard let strongself = self else { return }
      guard let strongContext = transitionContext else { return }
      strongself.provider.currentImageViewHidden = false
      strongself.delegate?.transitionDidFinishAnimation(transitionAnimator: strongself, transitionContext: strongContext, finished: !strongContext.transitionWasCancelled)
      strongself.transitionIsCompleted = !strongContext.transitionWasCancelled
      mockSourceImageView.removeFromSuperview()
      if strongContext.isInteractive {
        if strongContext.transitionWasCancelled {
          strongContext.cancelInteractiveTransition()
        } else {
          strongContext.finishInteractiveTransition()
        }
      }
      strongContext.completeTransition(!strongContext.transitionWasCancelled)
      strongself.provider.configuration.reloadImmersiveMode(!strongContext.transitionWasCancelled)
    }

    if transitionContext.isInteractive {
      interactiveImageViewTransformBlock = { [weak mockSourceImageView] in
        mockSourceImageView?.transform = $0
      }
      interactivePercentAnimationsBlock = { percent in
        animations(true, false, percent)
      }
      interactiveController?.continueAnimation = { [weak self, weak transitionContext] in
        self?.continueAnimations(using: transitionContext, animations: animations, completion: completion)
      }
    } else {
      performDefaultAnimations(duration: duration, isCancelled: false, animations: animations, completion: completion)
    }
  }

  func performDefaultAnimations(duration: TimeInterval, isCancelled: Bool, animations: @escaping (_ interactive: Bool, _ isCancelled: Bool, _ expectedEndingProgress: CGFloat) -> Void, completion: @escaping() -> Void) -> Void {
    switch option {
    case let .fallback(springDampingRatio, initialSpringVelocity, options):
      UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: springDampingRatio, initialSpringVelocity: initialSpringVelocity, options: options, animations: {
        animations(false, isCancelled, 1)
      }) { (finish) in
        completion()
      }
    case .perferred(let block):
      if #available(iOS 10.0, *) {
        animator = block(duration)
        animator?.addAnimations {
          animations(false, isCancelled, 1)
        }
        animator?.addCompletion { (postion) in
          completion()
        }
        animator?.startAnimation()
      } else {
        fatalError()
      }
    }
  }

  func continueAnimations(using transitionContext: UIViewControllerContextTransitioning?, animations: @escaping (_ interactive: Bool, _ isCancelled: Bool, _ expectedEndingProgress: CGFloat) -> Void, completion: @escaping() -> Void) -> Void {
    guard let strongContext = transitionContext else { return }
    guard let strongInteractiveController = interactiveController else { return }
    let isCancelled = strongContext.transitionWasCancelled
    let duration = self.duration * Double(1 - strongInteractiveController.progress)
    performDefaultAnimations(duration: duration, isCancelled: isCancelled, animations: animations, completion: completion)
  }

  public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == #keyPath(ZoomOutAnimatedInteractiveController.progress) {
      if let interactiveController = interactiveController {
        interactivePercentAnimationsBlock?(interactiveController.progress)
      }
    } else if keyPath == #keyPath(ZoomOutAnimatedInteractiveController.transform){
      if let change = change, let trans = change[NSKeyValueChangeKey.newKey] as? CGAffineTransform {
        interactiveImageViewTransformBlock?(trans)
      }
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  deinit {
    delegate?.transitionDidFinish(transitionAnimator: self, finished: transitionIsCompleted)
    if transitionIsCompleted {
      transferrer?.restoreNavigationControllerDelegate()
    }
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
