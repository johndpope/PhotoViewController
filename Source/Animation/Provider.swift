//
//  Animator.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

public protocol LargePhotoViewProvider: class {
  var currentImageViewHidden: Bool { set get }
  var currentImageViewFrame: CGRect? { get }
  var currentImage: UIImage? { get }
  var isModalTransition: Bool { get }
  var dismissalInteractiveController: ZoomOutAnimatedInteractiveController? { get }
  var configuration: PhotoViewConfiguration { get }
}

public struct SmallPhotoViewProvider {
  public let frame: CGRect?
  public let contentMode: ViewContentMode
  public let image: UIImage?
  public init(frame: CGRect?, contentMode: ViewContentMode, image: UIImage?) {
    self.frame = frame
    self.contentMode = contentMode
    self.image = image
  }
  public init(imageView: UIImageView, image: UIImage?) {
    self.frame = imageView.superview?.convert(imageView.frame, to: UIApplication.shared.keyWindow)
    self.contentMode = imageView.contentMode
    self.image = image
  }
}

public struct PhotoZoomInProvider {
  public let source: SmallPhotoViewProvider
  public let destionation: LargePhotoViewProvider
  public init(source: SmallPhotoViewProvider, destionation: LargePhotoViewProvider) {
      self.source = source
      self.destionation = destionation
  }
}

extension PhotoZoomInProvider: ZoomAnimatedTransitioningContentProvider {
  public var image: UIImage? {
    return source.image
  }
}

extension PhotoZoomInProvider: ZoomAnimatedTransitioningGeometryProvider {
  public var imageViewFrame: CGRect? {
    return source.frame
  }

  public var imageViewContentMode: ViewContentMode {
    return source.contentMode
  }
}

extension PhotoZoomInProvider: ZoomAnimatedTransitioningLargePhotoViewProvider {
  public var provider: LargePhotoViewProvider {
    return destionation
  }
}

extension PhotoZoomInProvider: ZoomAnimatedTransitioningProvider {}

public struct PhotoZoomOutProvider {
  public let source: LargePhotoViewProvider
  public let destionation: SmallPhotoViewProvider
  public init(source: LargePhotoViewProvider, destionation: SmallPhotoViewProvider) {
    self.source = source
    self.destionation = destionation
  }
}

extension PhotoZoomOutProvider: ZoomAnimatedTransitioningContentProvider {
  public var image: UIImage? {
    return source.currentImage
  }
}

extension PhotoZoomOutProvider: ZoomAnimatedTransitioningGeometryProvider {
  public var imageViewFrame: CGRect? {
    return destionation.frame
  }

  public var imageViewContentMode: ViewContentMode {
    return destionation.contentMode
  }
}

extension PhotoZoomOutProvider: ZoomAnimatedTransitioningLargePhotoViewProvider {
  public var provider: LargePhotoViewProvider {
    return source
  }
}

extension PhotoZoomOutProvider: ZoomAnimatedTransitioningProvider {}

public enum ImageZoomAnimationOption {
  case fallback(springDampingRatio: CGFloat, initialSpringVelocity: CGFloat, options: ViewAnimationOptions)
  @available(iOS 10.0, *)
  case perferred((TimeInterval) -> UIViewPropertyAnimator)
}

public protocol ImageZoomForceTouchProvider: class {
  var isForceTouching: Bool { set get }
  var nextForceTouchReceiver: ImageZoomForceTouchProvider? { get }
}
