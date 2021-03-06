//
//  PhotoViewManager.swift
//  PhotoViewController
//
//  Created by Felicity on 8/6/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit
import AVFoundation.AVUtilities

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

  public static let immersiveModeDidChange: Notification.Name = Notification.Name(rawValue: "PhotoViewConfigurationrImmersiveModeDidChange")

  public private(set) var notificationCenter: NotificationCenter

  public init(notificationCenter: NotificationCenter = .default) {
    self.notificationCenter = notificationCenter
  }

  public var longestPreviewingContentSize: CGSize = CGSize(width: 1, height: 6)

  /// for placeholder or content size, useful for 3d touch
  public var hintImage: UIImage?
  
  public var interactiveDismissScaleFactor: CGFloat = 0.5

  public var interactiveDismissDirection: PhotoViewDismissDirection = .all

  public var convertIndexPathFromUserToPage: ((_ userIndexPath: IndexPath, _ desiredLength: Int) -> IndexPath)?

  public var convertIndexPathFromPageToUser: (( _ templateIndexPath: IndexPath, _ pageIndexPath: IndexPath) -> IndexPath)?

  public var contentModeBlock: (( _ size: CGSize) -> PhotoViewContentMode?)?

  public func getPageIndexPath(form userIndexPath: IndexPath, desiredLength: Int) -> IndexPath {
    return convertIndexPathFromUserToPage?(userIndexPath, desiredLength) ?? IndexPath(indexes: userIndexPath.suffix(desiredLength))
  }

  public func getUserIndexPath(template templateIndexPath: IndexPath, form pageIndexPath: IndexPath) -> IndexPath {
    return convertIndexPathFromPageToUser?(templateIndexPath, pageIndexPath) ?? templateIndexPath.dropLast(pageIndexPath.count).appending(pageIndexPath)
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
