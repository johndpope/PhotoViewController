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
func __addConstraint<A, L: NSLayoutAnchor<A>>(fromView: UIView?, toView: UIView?, getAnchor: KeyPath<UIView, L>) {
  guard let view1 = fromView else { return }
  guard let view2 = toView else { return }
  view1[keyPath: getAnchor].constraint(equalTo: view2[keyPath: getAnchor]).isActive = true
}


func __addConstraint(fromView: UIView?, toView: UIView?, attribute: LayoutConstraintAttribute) {
  guard let view1 = fromView else { return }
  guard let view2 = toView else { return }
  NSLayoutConstraint(item: view1, attribute: attribute, relatedBy: .equal, toItem: view2, attribute: attribute, multiplier: 1.0, constant: 0.0).isActive = true
}

extension UIView {

  func inset(inView otherView: UIView) -> Void {
    if #available(iOS 9.0, *) {
      __addConstraint(fromView: self, toView: otherView, getAnchor: \.topAnchor)
      __addConstraint(fromView: self, toView: otherView, getAnchor: \.bottomAnchor)
      __addConstraint(fromView: self, toView: otherView, getAnchor: \.leftAnchor)
      __addConstraint(fromView: self, toView: otherView, getAnchor: \.rightAnchor)
    } else {
      __addConstraint(fromView: self, toView: otherView, attribute: .top)
      __addConstraint(fromView: self, toView: otherView, attribute: .bottom)
      __addConstraint(fromView: self, toView: otherView, attribute: .left)
      __addConstraint(fromView: self, toView: otherView, attribute: .right)
      // Fallback on earlier versions
    }
  }
}
