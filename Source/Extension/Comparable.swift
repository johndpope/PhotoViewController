//
//  Comparable.swift
//  PhotoViewController
//
//  Created by Felicity on 8/26/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation
extension Comparable {

  func clamp(_ minimum: Self, _ maximum: Self) -> Self {
    return min(max(minimum, self), maximum)
  }

}
