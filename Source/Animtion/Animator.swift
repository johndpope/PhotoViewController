//
//  Animator.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

#if swift(>=4.2)
public typealias ViewContentMode = UIView.ContentMode
public typealias ViewAnimationOptions = UIView.AnimationOptions
public typealias ViewAnimationCurve = UIView.AnimationCurve
#else
public typealias ViewContentMode = UIViewContentMode
public typealias ViewAnimationOptions = UIViewAnimationOptions
public typealias ViewAnimationCurve = UIViewAnimationCurve
#endif

public protocol ImageZoomProvider: class {
  var currentImageViewHidden: Bool { set get }
  var currentImageViewFrame: CGRect? { get }
  var currentImage: UIImage? { get }
  var isModalTransition: Bool { get }
  var dismissalInteractiveController: UIViewControllerInteractiveTransitioning? { get }
}

public enum ImageZoomAnimator {
  case showFromImageView(UIImageView, image: UIImage?, provider: ImageZoomProvider)
  case showFromImageViewFrame(CGRect, fromImageViewContentMode: ViewContentMode, image: UIImage?, provider: ImageZoomProvider)
  case dismissToImageView(UIImageView, provider: ImageZoomProvider)
  case dismissToImageViewFrame(CGRect, toImageViewContentMode: ViewContentMode, provider: ImageZoomProvider)
}

public enum ImageZoomAnimationOption {
  case fallback(springDampingRatio: CGFloat, initialSpringVelocity: CGFloat, options: ViewAnimationOptions)
  @available(iOS 10.0, *)
  case perferred((TimeInterval) -> UIViewPropertyAnimator)
}
