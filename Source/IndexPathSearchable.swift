//
//  IndexPathSearchable.swift
//  PhotoViewController
//
//  Created by Felicity on 8/8/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation

public protocol IndexPathSearchable {
  func allIndexPaths(where predicate: (MediaResource) -> Bool, matchFirst: Bool) -> [IndexPath]
}

extension MediaResource: IndexPathSearchable {

  public func allIndexPaths(where predicate: (MediaResource) -> Bool, matchFirst: Bool) -> [IndexPath] {
    if predicate(self) {
      return [IndexPath(index: Int.max)]
    }
    return []
  }

}

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

extension Array: IndexPathSearchable where Element: IndexPathSearchable {

  public var indexPathLength: Int {
    return allIndexPaths(where: { _ in true }, matchFirst: true).first?.count ?? 0
  }

  public func allIndexPaths(where predicate: (MediaResource) -> Bool, matchFirst: Bool) -> [IndexPath] {
    var stopSign: Bool = false
    let a = enumerated().map({ (offset, element) -> [[Int]] in
      guard !stopSign else { return [] }
      let subIndexPaths = element.allIndexPaths(where: predicate, matchFirst: matchFirst)
      stopSign = matchFirst && subIndexPaths.count > 0
      let newSubIndexPaths = subIndexPaths.map({ indexPath -> [Int] in
        if indexPath.count == 1, indexPath[0] == Int.max {
          return [offset]
        } else {
          var array = Array<Int>(indexPath)
          array.insert(offset, at: 0)
          return array
        }
      })
      return newSubIndexPaths
    })
    let b = a.reduce([[Int]](), +)
    return b.map({ IndexPath(indexes:$0) })
  }

  public func nextIndexPath(of indexPath: IndexPath, forward: Bool, loop: Bool) -> IndexPath? {
    return allIndexPaths(where: { _ in true }, matchFirst: false).nextElement(of: indexPath, forward: forward, loop: loop)
  }

  public func firstIndexPath(where predicate: (MediaResource) -> Bool) -> IndexPath? {
    return allIndexPaths(where: predicate, matchFirst: true).first
  }

  @discardableResult
  public mutating func removeItemAt(indexPath: IndexPath) -> MediaResource {
    return getResource(at: indexPath) { (array, index) in array.remove(at: index) }
  }

  public subscript(resource indexPath: IndexPath) -> MediaResource {
    mutating get { return getResource(at: indexPath) }
  }
}

extension Array {

  mutating func unsafeLoop(indexPath: IndexPath, _ action: ((inout [Any], Int) -> Void)) -> Void {
    assert(indexPath.count > 0)
    var array: [Any] = self
    let index = indexPath[0]
    if indexPath.count == 1 {
      action(&array, index)
    } else {
      var subArray = array[index] as! [Any]
      subArray.unsafeLoop(indexPath: indexPath.dropFirst(), action)
      array[index] = subArray
    }
    self = array as! [Element]
  }

  mutating func getResource(at indexPath: IndexPath, _ action: ((inout [Any], Int) -> Void)? = nil) -> MediaResource {
    var media: Any?
    unsafeLoop(indexPath: indexPath) { (array, index) in
      media = array[index]
      action?(&array, index)
    }
    return media as! MediaResource
  }

}
