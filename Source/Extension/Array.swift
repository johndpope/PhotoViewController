//
//  Array.swift
//  PhotoViewController
//
//  Created by Felicity on 11/10/19.
//  Copyright © 2019 Prime. All rights reserved.
//

import Foundation

extension Array where Element: Equatable {
  public func nextElement(of element: Element, forward: Bool, loop: Bool) -> Element? {
    func incrementIndex(forward: Bool) -> ((Int) -> Int) {
      return {
        forward ? $0 + 1 : $0 - 1
      }
    }
    #if swift(>=4.2)
    let flatIndex = firstIndex(of: element)
    #else
    let flatIndex = index(of: element)
    #endif
    guard let flatIndexFound = flatIndex else { return nil }
    let destinationFlatIndex: Int = incrementIndex(forward: forward)(flatIndexFound)
    let nextFlatIndex: Int = loop ? ((destinationFlatIndex + count) % count) : destinationFlatIndex
    return indices.contains(nextFlatIndex) ? self[nextFlatIndex] : nil
  }
}
