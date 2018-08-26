//
//  UIView.swift
//  PhotoViewController
//
//  Created by Felicity on 8/13/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit
// MARK: - Auto Layout

@available(iOS 9.0, *)
func __addConstraint<R>(fromView: UIView?, toView: UIView?, getAnchor: (UIView) -> NSLayoutAnchor<R>) {
  guard let view1 = fromView else { return }
  guard let view2 = toView else { return }
  getAnchor(view1).constraint(equalTo: getAnchor(view2)).isActive = true
}


func __addConstraint(fromView: UIView?, toView: UIView?, attribute: LayoutConstraintAttribute) {
  guard let view1 = fromView else { return }
  guard let view2 = toView else { return }
  NSLayoutConstraint(item: view1, attribute: attribute, relatedBy: .equal, toItem: view2, attribute: attribute, multiplier: 1.0, constant: 0.0).isActive = true
}

extension UIView {

  func inset(inView otherView: UIView) -> Void {
    if #available(iOS 9.0, *) {
      __addConstraint(fromView: self, toView: otherView, getAnchor: { $0.topAnchor })
      __addConstraint(fromView: self, toView: otherView, getAnchor: { $0.bottomAnchor })
      __addConstraint(fromView: self, toView: otherView, getAnchor: { $0.leftAnchor })
      __addConstraint(fromView: self, toView: otherView, getAnchor: { $0.rightAnchor })
    } else {
      __addConstraint(fromView: self, toView: otherView, attribute: .top)
      __addConstraint(fromView: self, toView: otherView, attribute: .bottom)
      __addConstraint(fromView: self, toView: otherView, attribute: .left)
      __addConstraint(fromView: self, toView: otherView, attribute: .right)
      // Fallback on earlier versions
    }
  }
}
