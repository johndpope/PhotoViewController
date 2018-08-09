//
//  UIScrollView.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation

extension UIScrollView {

  var belowMinZoomScale: Bool {
    return zoomScale < minimumZoomScale
  }

  var reachMinZoomScale: Bool {
    return zoomScale <= minimumZoomScale
  }

  var reachMaxZoomScale: Bool {
    return zoomScale >= maximumZoomScale
  }

  func zoomToMin(at point: CGPoint, _ animated: Bool = true) -> Void {
    setZoomScale(minimumZoomScale, animated: animated)
  }

  func zoomToMax(at point: CGPoint, _ animated: Bool = true) -> Void {
    zoom(to: CGRect(origin: point, size: .zero), animated: animated)
  }

}
