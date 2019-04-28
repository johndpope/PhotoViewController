//
//  PhotoViewManager.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit
import AVFoundation.AVUtilities

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

public struct PhotoViewDismissDirection: OptionSet {

  public typealias RawValue = Int
  public let rawValue: RawValue
  public init(rawValue: RawValue) {
    self.rawValue = rawValue
  }

  public static let none: PhotoViewDismissDirection = PhotoViewDismissDirection(rawValue: 0)

  public static let left: PhotoViewDismissDirection = PhotoViewDismissDirection(rawValue: 1 << 0)
  public static let right: PhotoViewDismissDirection = PhotoViewDismissDirection(rawValue: 1 << 1)
  public static let top: PhotoViewDismissDirection = PhotoViewDismissDirection(rawValue: 1 << 2)
  public static let bottom: PhotoViewDismissDirection = PhotoViewDismissDirection(rawValue: 1 << 3)

  public static let all: PhotoViewDismissDirection = [.left, .right, .top, .bottom]

}

open class PhotoViewConfiguration {

  public static var immersiveModeDidChange: Notification.Name {
    return Notification.Name(rawValue: "PhotoViewManagerImmersiveModeDidChange")
  }

  public var notificationCenter: NotificationCenter

  public init(notificationCenter: NotificationCenter = .default) {
    self.notificationCenter = notificationCenter
  }

  public private(set) var immersiveMode: PhotoImmersiveMode = .normal {
    didSet {
      notificationCenter.post(name: PhotoViewConfiguration.immersiveModeDidChange, object: nil)
    }
  }

  public var longestPreviewingContentSize: CGSize = CGSize(width: 1, height: 6)

  /// for placeholder or content size, useful for 3d touch
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

  public var interactiveDismissDirection: PhotoViewDismissDirection = .all

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

  public var portraitScreenBounds: CGRect {
    let rect = UIScreen.main.bounds
    return CGRect(x: 0, y: 0, width: min(rect.width, rect.height), height: max(rect.width, rect.height))
  }

  private func defaultContentMode(for size: CGSize) -> PhotoViewContentMode? {
    guard size.isValid else { return nil }
    if size.aspectRatio > portraitScreenBounds.size.aspectRatio {
      return .fitWidth(.center)
    } else {
      return .fitScreen
    }
  }

  public func contentSize(forPreviewing previewing: Bool, resourceSize: CGSize?) -> CGSize {
    let bounds = UIScreen.main.bounds
    let boundsSize = bounds.size
    guard previewing else { return boundsSize }
    let hintSize = hintImage?.size
    guard let size = hintSize ?? resourceSize else { return boundsSize }
    guard let contentMode = defaultContentMode(for: size) else { return boundsSize }
    switch contentMode {
    case .fitScreen:
      return AVMakeRect(aspectRatio: size, insideRect: bounds).size
    case .fitWidth:
      let longest = AVMakeRect(aspectRatio: longestPreviewingContentSize, insideRect: bounds)
      let desired = AVMakeRect(aspectRatio: size, insideRect: bounds)
      return longest.union(desired).size
    }
  }

}
