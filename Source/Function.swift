//
//  Function.swift
//  PhotoViewController
//
//  Created by Felicity on 8/26/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit


func upsearch<T, U>(from starter: T, maximumSearch: Int, type: U.Type, father: (T?) -> T?) -> U? {
  var number = 0
  var _nextFinder: T? = starter
  while !(_nextFinder is U), number < maximumSearch {
    _nextFinder = father(_nextFinder)
    number += 1
  }
  return _nextFinder as? U
}

func drawImage(inSize size: CGSize, opaque: Bool = false, scale: CGFloat = 0, action: ((CGContext?) -> Void)) -> UIImage? {
  if #available(iOS 10.0, *) {
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = opaque
    format.scale = scale
    return UIGraphicsImageRenderer(size: size).image { (context) in
      action(context.cgContext)
    }
  } else {
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
    action(UIGraphicsGetCurrentContext())
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
  }
}


@inline(__always)
func debuglog(_ items: Any...) -> Void {
  #if DEBUG
  print(items)
  #endif
}
