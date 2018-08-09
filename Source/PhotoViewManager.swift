//
//  PhotoViewManager.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation


public extension Notification.Name {
  public static var PhotoViewControllerImmersionDidChange: Notification.Name {
    return Notification.Name(rawValue: "PhotoViewControllerImmersionDidChange")
  }
}

public enum PhotoViewTapAction {
  case toggleImmersingState
  case dismiss
}


public enum PhotoImmersingState {
  case normal
  case immersed
}



open class PhotoViewManager {

  public var notificationCenter: NotificationCenter

  public init(notificationCenter: NotificationCenter = .default) {
    self.notificationCenter = notificationCenter
  }

  public static let `default`: PhotoViewManager = PhotoViewManager()

  public private(set) var immersingState: PhotoImmersingState = .normal {
    didSet {
      notificationCenter.post(name: NSNotification.Name.PhotoViewControllerImmersionDidChange, object: nil)
    }
  }

  public var viewTapAction: PhotoViewTapAction = .toggleImmersingState

  public var defaultImmersingState: PhotoImmersingState = .normal

  public var enabledImmersingState: [PhotoImmersingState] = [.normal, .immersed]

  public func nextImmersingState() {
    let future: PhotoImmersingState
    switch immersingState {
    case .normal:
      future = .immersed
    case .immersed:
      future = .normal
    }
    if enabledImmersingState.contains(future) {
      immersingState = future
    }
  }

  public func forceSetImmersingState(_ state: PhotoImmersingState) {
    if enabledImmersingState.contains(state) {
      immersingState = state
    }
  }

  public func resetImmersingState() {
    if enabledImmersingState.contains(defaultImmersingState) {
      immersingState = defaultImmersingState
    }
  }

  public var pagingIndexPathBlock: ((_ userIndexPath: IndexPath, _ desiredLength: Int) -> IndexPath)?

  public var userIndexPathBlock: (( _ templateIndexPath: IndexPath, _ pagingIndexPath: IndexPath) -> IndexPath)?

  public func pagingIndexPath(form userIndexPath: IndexPath, desiredLength: Int) -> IndexPath {
    return pagingIndexPathBlock?(userIndexPath, desiredLength) ?? IndexPath(indexes: userIndexPath.suffix(desiredLength))
  }

  public func userIndexPath(template templateIndexPath: IndexPath, form pagingIndexPath: IndexPath) -> IndexPath {
    return userIndexPathBlock?(templateIndexPath, pagingIndexPath) ?? templateIndexPath.dropLast(pagingIndexPath.count).appending(pagingIndexPath)
  }


}
