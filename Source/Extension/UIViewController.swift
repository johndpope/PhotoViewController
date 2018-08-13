//
//  UIViewController.swift
//  PhotoViewController
//
//  Created by Felicity on 8/13/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation

import UIKit

extension UIViewController {

  var pageControllerView: UIView? {
    if view.next is ImageZoomProvider {
      return view
    }
    return view.subviews.first(where: { $0.next is ImageZoomProvider })
  }

  func snapshotViewOnlyPageView(afterScreenUpdates: Bool) -> UIView? {
    return pageControllerView?.snapshotView(afterScreenUpdates: afterScreenUpdates)
  }

  func snapshotViewExceptPageView(afterScreenUpdates: Bool) -> UIView? {
    if pageControllerView == view {
      return UIView(frame: view.bounds)
    }
    let snapshotContainerView = UIView(frame: view.bounds)
    view.subviews.forEach { (sub) in
      if sub != pageControllerView {
        if let subSnap = sub.snapshotView(afterScreenUpdates: true) {
          snapshotContainerView.addSubview(subSnap)
          subSnap.frame = sub.frame
        }
      }
    }
    return snapshotContainerView
  }

}
