//
//  ResourceSequence.swift
//  PhotoViewController
//
//  Created by Felicity on 11/10/19.
//  Copyright © 2019 Prime. All rights reserved.
//

import Foundation

public protocol ResourceSequence {
  static var indexPathLength: Int { get }
  subscript(indexPath: IndexPath) -> MediaResource { get }
  func filter(where predicate: (MediaResource) -> Bool) -> [IndexPath]
  func indexPath(after indexPath: IndexPath, loop: Bool) -> IndexPath?
  func indexPath(before indexPath: IndexPath, loop: Bool) -> IndexPath?
  mutating func remove(at indexPath: IndexPath) -> MediaResource?
}

extension ResourceSequence {
  public var allIndexPath: [IndexPath] {
    return filter(where: { _ in true })
  }
  public func indexPath(after indexPath: IndexPath, loop: Bool) -> IndexPath? {
    return allIndexPath.nextElement(of: indexPath, forward: true, loop: loop)
  }
  public func indexPath(before indexPath: IndexPath, loop: Bool) -> IndexPath? {
    return allIndexPath.nextElement(of: indexPath, forward: false, loop: loop)
  }
  public mutating func remove(at indexPath: IndexPath) -> MediaResource? {
    return nil
  }
}

extension MediaResource: ResourceSequence {
  
  public static var indexPathLength: Int { return 0 }
  
  public subscript(indexPath: IndexPath) -> MediaResource { assert(indexPath == IndexPath()); return self }
  
  public func filter(where predicate: (MediaResource) -> Bool) -> [IndexPath] { guard predicate(self) else { return [] }; return [IndexPath()] }

}

extension Array: ResourceSequence where Element: ResourceSequence {

  public subscript(indexPath: IndexPath) -> MediaResource {
    guard let first = indexPath.first, indices.contains(first) else {
      fatalError()
    }
    return self[first][indexPath.dropFirst()]
  }
  
  public static var indexPathLength: Int {
    return Element.indexPathLength + 1
  }
  
  public func filter(where predicate: (MediaResource) -> Bool) -> [IndexPath] {
    return self.enumerated()
      .compactMap({ t -> (Int, [IndexPath])? in let s = t.1.filter(where: predicate); return s.isEmpty ? nil : (t.0, s) })
      .flatMap({ s in s.1.map({ i in IndexPath(index: s.0).appending(i) }) })
  }
  
  public mutating func remove(at indexPath: IndexPath) -> MediaResource? {
    guard let first = indexPath.first, indices.contains(first) else {
      fatalError()
    }
    if self[first] is MediaResource {
      return self.remove(at: first) as? MediaResource
    } else {
      return self[first].remove(at: indexPath.dropFirst())
    }
  }
  
}
