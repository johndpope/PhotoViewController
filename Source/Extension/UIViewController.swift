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
    if view.next is LargePhotoViewProvider {
      return view
    }
    return view.subviews.first(where: { $0.next is LargePhotoViewProvider })
  }

  func snapshotViewOnlyPageView(afterScreenUpdates: Bool) -> UIView? {
    return pageControllerView?.snapshotView(afterScreenUpdates: afterScreenUpdates)
  }

  func snapshotViewExceptPageView(afterScreenUpdates: Bool) -> UIView? {
    if pageControllerView == view {
      return nil
    }
    let snapshotContainerView = UIView(frame: view.bounds)
    snapshotContainerView.backgroundColor = UIColor.clear
    view.subviews.forEach { (sub) in
      if sub != pageControllerView {
        if let subSnap = sub.snapshotView(afterScreenUpdates: afterScreenUpdates) {
          snapshotContainerView.addSubview(subSnap)
          subSnap.frame = sub.frame
        }
      }
    }
    return snapshotContainerView
  }

}
