//
//  MediaResource.swift
//  PhotoViewController
//
//  Created by Felicity on 8/2/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit
import PhotosUI

public enum MediaResourceType {
  case image
  @available(iOS 9.1, *)
  case livePhoto
  case gif
  case unspecified
}

public enum MediaResourceView {
  case image(UIImageView?)
  @available(iOS 9.1, *)
  case livePhoto(PHLivePhotoView?, UIImageView?)
  case custom(UIView?, UIImageView?)
  var imageView: UIImageView? {
    switch self {
    case let .image(v):
      return v
    case let .livePhoto(_, v):
      return v
    case let .custom(_, v):
      return v
    }
  }
  @available(iOS 9.1, *)
  var livePhotoView: PHLivePhotoView? {
    switch self {
    case let .livePhoto(v, _):
      return v
    default:
      return nil
    }
  }
  var customView: UIView? {
    switch self {
    case let .custom(v, _):
      return v
    default:
      return nil
    }
  }
}

public typealias MediaResourceFetching = (MediaResourceView, MediaResource) -> CGSize?

open class MediaResource {
  public let type: MediaResourceType
  /// for hash, like finding index
  public let identifier: String
  /// load data
  private var fetching: MediaResourceFetching
  
  public var display: (MediaResourceView) -> CGSize? { return { [unowned self] in self.fetching($0, self) } }

  open private(set) var contentSize: CGSize = .zero

  open var removing: Bool = false

  /// init
  ///
  /// - Parameters:
  ///   - identifier: id
  ///   - fetching: load data
  public init(type: MediaResourceType, identifier: String, fetching: @escaping MediaResourceFetching) {
    self.identifier = identifier
    self.fetching = fetching
    self.type = type
  }


  /// init
  ///
  /// - Parameters:
  ///   - identifier: id
  ///   - setImageBlock: load data
  public convenience init(setImageBlock: @escaping ((UIImageView?) -> Void)) {
    self.init(type: .image, identifier: UUID().uuidString) { (view, _) in
      setImageBlock(view.imageView)
      return nil
    }
  }

  /// init
  ///
  /// - Parameters:
  ///   - identifier: id
  ///   - setLivePhotoBlock: load data, set placeholder
  @available(iOS 9.1, *)
  public convenience init(setLivePhotoBlock: @escaping ((PHLivePhotoView?, UIImageView?) -> CGSize)) {
    self.init(type: .livePhoto, identifier: UUID().uuidString) { (view, _) in
      return setLivePhotoBlock(view.livePhotoView, view.imageView)
    }
  }

  /// display
  ///
  /// - Parameter imageView: imageView
  open func displayImage(inImageView imageView: UIImageView?) {
    _ = display(.image(imageView))
  }

  @available(iOS 9.1, *)
  /// display live photo
  ///
  /// - Parameters:
  ///   - livePhotView: livePhotView
  ///   - imageView: imageView, for placeholder
  open func displayLivePhoto(inLivePhotView livePhotView: PHLivePhotoView?, inImageView imageView: UIImageView?) {
    self.contentSize = display(.livePhoto(livePhotView, imageView)) ?? .zero
  }

}

extension MediaResource: Equatable {
  public static func == (lhs: MediaResource, rhs: MediaResource) -> Bool {
    return lhs.identifier == rhs.identifier
  }
}

