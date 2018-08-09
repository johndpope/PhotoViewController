//
//  MediaResource.swift
//  PhotoViewController
//
//  Created by Felicity on 8/2/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

public enum MediaResourceDealing {
  case image(UIImageView?)
}

public typealias MediaResourceRetrieving = (MediaResourceDealing) -> Void



open class MediaResource {
  /// for hash, like finding index
  open var identifier: String
  /// load data
  open var retrieving: MediaResourceRetrieving

  /// init
  ///
  /// - Parameters:
  ///   - identifier: id
  ///   - retrieving: load data
  public init(identifier: String, retrieving: @escaping MediaResourceRetrieving) {
    self.identifier = identifier
    self.retrieving = retrieving
  }


  /// init
  ///
  /// - Parameters:
  ///   - identifier: id
  ///   - setImageBlock: load data
  public convenience init(setImageBlock: @escaping ((UIImageView?) -> Void)) {
    self.init(identifier: UUID().uuidString, retrieving: {
      switch $0 {
      case .image(let imageView):
        setImageBlock(imageView)
      }
    })
  }


  /// display
  ///
  /// - Parameter imageView: imageView
  open func display(inImageView imageView: UIImageView?) {
    retrieving(.image(imageView))
  }

}

extension MediaResource: Equatable {
  public static func == (lhs: MediaResource, rhs: MediaResource) -> Bool {
    return lhs.identifier == rhs.identifier
  }
}





