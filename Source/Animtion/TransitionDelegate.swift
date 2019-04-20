//
//  PhotoZoomInOutTransitionProvider.swift
//  PhotoViewController
//
//  Created by Felicity on 4/20/19.
//  Copyright © 2019 Prime. All rights reserved.
//

import UIKit

public protocol PhotoZoomInOutTransitionProviderDelegate: NSObjectProtocol {
  func photoZoomInTransition(incoming viewController: UIViewController) -> UIViewControllerAnimatedTransitioning?
  func photoZoomOutTransition(outgoing viewController: UIViewController) -> UIViewControllerAnimatedTransitioning?
}

open class PhotoZoomInOutTransitionProvider: NSObject, UIViewControllerTransitioningDelegate, UINavigationControllerDelegate {

  weak var delegate: PhotoZoomInOutTransitionProviderDelegate?

  public init(delegate: PhotoZoomInOutTransitionProviderDelegate) {
    super.init()
    self.delegate = delegate
  }

  func photoZoomInTransition(incoming viewController: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return delegate?.photoZoomInTransition(incoming: viewController)
  }

  func photoZoomOutTransition(outgoing viewController: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return delegate?.photoZoomOutTransition(outgoing: viewController)
  }

  open func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return photoZoomInTransition(incoming: presented)
  }

  open func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return photoZoomOutTransition(outgoing:dismissed)
  }

  open func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    return (animator as? ZoomOutAnimatedTransitioning)?.interactiveTransitioning
  }

  #if swift(>=4.2)
  public typealias NavigationControllerOperation = UINavigationController.Operation
  #else
  public typealias NavigationControllerOperation = UINavigationControllerOperation
  #endif

  open func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: NavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    switch operation {
    case .push:
      return photoZoomInTransition(incoming: toVC)
    case .pop:
      return photoZoomOutTransition(outgoing: fromVC)
    case .none:
      return nil
    @unknown default:
      return nil
    }
  }

  open func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    return (animationController as? ZoomOutAnimatedTransitioning)?.interactiveTransitioning
  }

}
