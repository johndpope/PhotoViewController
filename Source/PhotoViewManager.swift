//
//  PhotoViewManager.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation


public extension Notification.Name {
  public static var PhotoViewControllerImmersiveModeDidChange: Notification.Name {
    return Notification.Name(rawValue: "PhotoViewControllerImmersiveModeDidChange")
  }
}

public enum PhotoViewTapAction {
  case toggleImmersiveMode
  case dismiss
}


public enum PhotoImmersiveMode {
  case normal
  case immersive
}

public enum PhotoViewContentPosition {
  case top
  case center
}

public enum PhotoViewContentMode {
  case fitScreen
  case fitWidth(PhotoViewContentPosition)
}

open class PhotoViewManager {

  public var notificationCenter: NotificationCenter

  public init(notificationCenter: NotificationCenter = .default) {
    self.notificationCenter = notificationCenter
  }

  public static let `default`: PhotoViewManager = PhotoViewManager()

  public private(set) var immersiveMode: PhotoImmersiveMode = .normal {
    didSet {
      notificationCenter.post(name: NSNotification.Name.PhotoViewControllerImmersiveModeDidChange, object: nil)
    }
  }

  public var hintImage: UIImage?

  public var viewTapAction: PhotoViewTapAction = .toggleImmersiveMode

  public var defaultImmersiveMode: PhotoImmersiveMode = .normal

  public var enabledImmersiveMode: [PhotoImmersiveMode] = [.normal, .immersive]

  public func nextImmersiveMode() {
    let future: PhotoImmersiveMode
    switch immersiveMode {
    case .normal:
      future = .immersive
    case .immersive:
      future = .normal
    }
    if enabledImmersiveMode.contains(future) {
      immersiveMode = future
    }
  }

  public var interactiveDismissScaleFactor: CGFloat = 0.5


  public func forceSetImmersiveMode(_ state: PhotoImmersiveMode) {
    if enabledImmersiveMode.contains(state) {
      immersiveMode = state
    }
  }

  public func reloadImmersiveMode(_ reset: Bool) {
    let state = reset ? defaultImmersiveMode : immersiveMode
    if enabledImmersiveMode.contains(state) {
      immersiveMode = state
    }
  }

  public var pagingIndexPathBlock: ((_ userIndexPath: IndexPath, _ desiredLength: Int) -> IndexPath)?

  public var userIndexPathBlock: (( _ templateIndexPath: IndexPath, _ pagingIndexPath: IndexPath) -> IndexPath)?

  public var contentModeBlock: (( _ size: CGSize) -> PhotoViewContentMode?)?

  public func pagingIndexPath(form userIndexPath: IndexPath, desiredLength: Int) -> IndexPath {
    return pagingIndexPathBlock?(userIndexPath, desiredLength) ?? IndexPath(indexes: userIndexPath.suffix(desiredLength))
  }

  public func userIndexPath(template templateIndexPath: IndexPath, form pagingIndexPath: IndexPath) -> IndexPath {
    return userIndexPathBlock?(templateIndexPath, pagingIndexPath) ?? templateIndexPath.dropLast(pagingIndexPath.count).appending(pagingIndexPath)
  }

  public func contenMode(for size: CGSize) -> PhotoViewContentMode? {
    guard size.isValid else { return nil }
    return contentModeBlock?(size) ?? defaultContentMode(for:size)
  }

  private func defaultContentMode(for size: CGSize) -> PhotoViewContentMode? {
    guard size.isValid else { return nil }
    if size.aspectRatio < UIScreen.main.bounds.size.aspectRatio {
      return .fitWidth(.center)
    } else {
      return .fitScreen
    }
  }

}
