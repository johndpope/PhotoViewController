//
//  CGAffineTransform.swift
//  PhotoViewController
//
//  Created by Felicity on 8/26/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation


extension CGAffineTransform {
  func makeScale(to scale: CGFloat, ratate angle: CGFloat = 0) -> CGAffineTransform {
    let scaleTransform = self.concatenating(CGAffineTransform(scaleX: scale, y: scale))
    let rotateTransform = scaleTransform.concatenating(CGAffineTransform(rotationAngle: angle))
    return rotateTransform
  }
}

