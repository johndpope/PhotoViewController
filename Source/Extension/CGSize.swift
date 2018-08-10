//
//  CGSize.swift
//  PhotoViewController
//
//  Created by Felicity on 8/10/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

public extension CGSize {
  public var isValid: Bool {
    return width > 0 && height > 0
  }
  public var aspectRatio: CGFloat {
    return width / height
  }
}
