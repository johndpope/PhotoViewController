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

public enum MediaResourceDealing {
  case image(UIImageView?)
  @available(iOS 9.1, *)
  case livePhoto(PHLivePhotoView?, UIImageView?)
  case custom(UIView?, UIImageView?)
}

public typealias MediaResourceRetrieving = (MediaResourceDealing) -> CGSize?

open class MediaResource {
  /// for hash, like finding index
  open var identifier: String
  /// load data
  open var retrieving: MediaResourceRetrieving

  open var contentSize: CGSize = .zero

  public let type: MediaResourceType

  public var removing: Bool = false

  /// init
  ///
  /// - Parameters:
  ///   - identifier: id
  ///   - retrieving: load data
  public init(type: MediaResourceType = .unspecified, identifier: String, retrieving: @escaping MediaResourceRetrieving) {
    self.identifier = identifier
    self.retrieving = retrieving
    self.type = type
  }


  /// init
  ///
  /// - Parameters:
  ///   - identifier: id
  ///   - setImageBlock: load data
  public convenience init(setImageBlock: @escaping ((UIImageView?) -> Void)) {
    self.init(type: .image, identifier: UUID().uuidString, retrieving: {
      switch $0 {
      case .image(let imageView):
        setImageBlock(imageView)
      default:
        break
      }
      return nil
    })
  }

  /// init
  ///
  /// - Parameters:
  ///   - identifier: id
  ///   - setLivePhotoBlock: load data, set placeholder
  @available(iOS 9.1, *)
  public convenience init(setLivePhotoBlock: @escaping ((PHLivePhotoView?, UIImageView?) -> CGSize)) {
    self.init(type: .livePhoto, identifier: UUID().uuidString, retrieving: {
      switch $0 {
      case let .livePhoto(livePhotView, imageView):
        let size = setLivePhotoBlock(livePhotView, imageView)
        return size
      default:
        break
      }
      return .zero
    })
  }

  /// display
  ///
  /// - Parameter imageView: imageView
  open func display(inImageView imageView: UIImageView?) {
    _ = retrieving(.image(imageView))
  }

  @available(iOS 9.1, *)
  /// display live photo
  ///
  /// - Parameters:
  ///   - livePhotView: livePhotView
  ///   - imageView: imageView, for placeholder
  open func displayLivePhoto(inLivePhotView livePhotView: PHLivePhotoView?, inImageView imageView: UIImageView?) {
    self.contentSize = retrieving(.livePhoto(livePhotView, imageView)) ?? .zero
  }

}

extension MediaResource: Equatable {
  public static func == (lhs: MediaResource, rhs: MediaResource) -> Bool {
    return lhs.identifier == rhs.identifier
  }
}

