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
      return [[Int.max]]
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
    let allElements = self
    if let flatIndex = allElements.firstIndex(of: element) {
      var nextFlatIndex: Int?
      let destinationFlatIndex: Int
      if forward {
        destinationFlatIndex = flatIndex + 1
      } else {
        destinationFlatIndex = flatIndex - 1
      }
      if loop {
        nextFlatIndex = (destinationFlatIndex + count) % count
      } else if allElements.indices.contains(destinationFlatIndex) {
        nextFlatIndex = destinationFlatIndex
      }
      if let nextFlatIndex = nextFlatIndex {
        return allElements[nextFlatIndex]
      }
    }
    return nil
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

  func unsafeLoop(indexPath: IndexPath, _ action: (([Any], Int) -> Void)) -> Void {
    var array: [Any] = self
    indexPath.forEach { (index) in
      if array is [MediaResource] {
        action(array, index)
      } else if let subArray = array[index] as? [Any] {
        array = subArray
      }
    }
  }

  public subscript(resource indexPath: IndexPath) -> MediaResource {
    get {
      var ret: Any?
      unsafeLoop(indexPath: indexPath) { (typeSubArray, index) in
        ret = typeSubArray[index]
      }
      return ret as! MediaResource
    }
  }
}


//func TESTAllIndexPaths() -> Void {
//  var tests: [[[MediaResource]]] = []
//  for i in 0..<10 {
//    tests.append([])
//    for j in 0..<10 {
//      tests[i].append([])
//      for _ in 0..<10 {
//        tests[i][j].append(MediaResource(setImageBlock: { _ in }))
//      }
//    }
//  }
//
//  let k = MediaResource(identifier: "10", retrieving: { _ in })
//
//  tests[2][5][1] = k
//  tests[3][8][0] = k
//  tests[4][4][5] = k
//  tests[6][7][9] = k
//
//  print(tests.firstIndexPath(where: { $0.identifier == "10" }) as Any)
//  print(tests.allIndexPaths(where: { $0.identifier == "10" }, matchFirst: true))
//}
