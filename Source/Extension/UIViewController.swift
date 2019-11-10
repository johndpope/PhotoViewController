//
//  UIViewController.swift
//  PhotoViewController
//
//  Created by Felicity on 8/13/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation

import UIKit

public extension UIViewController {

  func prepareForZoomTransitioning(pageController: UIViewController,
                                   transferrer: UINavigationControllerDelegateTransferrer,
                                   transitioningDelegate: UIViewControllerTransitioningDelegate & UINavigationControllerDelegate,
                                   modal: Bool) {
    if modal {
      pageController.transitioningDelegate = transitioningDelegate
      pageController.modalPresentationStyle = .custom
    } else {
      transferrer.transferDelegate(for: navigationController)
      navigationController?.delegate = transitioningDelegate
    }
  }

}
