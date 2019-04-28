//
//  Zoom.swift
//  PhotoViewController
//
//  Created by Felicity on 4/28/19.
//  Copyright © 2019 Prime. All rights reserved.
//

import UIKit

public enum ZoomAnimatedTransitioningDirection {
  case incoming
  case outgoing
}

public protocol ZoomAnimatedTransitioningDelegate: class {

  func zoomTransition(direction: ZoomAnimatedTransitioningDirection, viewController: UIViewController) -> ZoomAnimatedTransitioning?
  
  func transitionWillBegin(transitionAnimator: ZoomAnimatedTransitioning, transitionContext: UIViewControllerContextTransitioning)
  func transitionDidFinish(transitionAnimator: ZoomAnimatedTransitioning, finished: Bool)

  func transitionWillBeginAnimation(transitionAnimator: ZoomAnimatedTransitioning, transitionContext: UIViewControllerContextTransitioning, imageView: UIImageView)
  func transitionDidFinishAnimation(transitionAnimator: ZoomAnimatedTransitioning, transitionContext: UIViewControllerContextTransitioning, finished: Bool)

  func transitionUserAnimation(transitionAnimator: ZoomAnimatedTransitioning?, transitionContext: UIViewControllerContextTransitioning?, isInteractive: Bool, isCancelled: Bool, progress: CGFloat?, imageView: UIImageView)
}

public protocol ZoomAnimatedTransitioningContentProvider {
  var image: UIImage? { get }
}

public protocol ZoomAnimatedTransitioningGeometryProvider {
  var imageViewFrame: CGRect? { get }
  var imageViewContentMode: ViewContentMode { get }
}

public protocol ZoomAnimatedTransitioningLargePhotoViewProvider {
  var provider: LargePhotoViewProvider { get }
}

public protocol ZoomAnimatedTransitioningProvider: ZoomAnimatedTransitioningContentProvider, ZoomAnimatedTransitioningGeometryProvider, ZoomAnimatedTransitioningLargePhotoViewProvider {

}



public class ZoomAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {

  public weak var delegate: ZoomAnimatedTransitioningDelegate?

  public let duration: TimeInterval
  public let option: ImageZoomAnimationOption
  public let image: UIImage?
  public let imageViewFrame: CGRect?
  public let imageViewContentMode: ViewContentMode
  public let provider: LargePhotoViewProvider

  public var direction: ZoomAnimatedTransitioningDirection {
    fatalError()
  }

  public init(duration: TimeInterval,
              option: ImageZoomAnimationOption,
              provider: ZoomAnimatedTransitioningProvider) {
    self.duration = duration
    self.option = option
    self.image = provider.image
    self.imageViewFrame = provider.imageViewFrame
    self.imageViewContentMode = provider.imageViewContentMode
    self.provider = provider.provider
  }

  public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return duration
  }

  public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {

  }

}
