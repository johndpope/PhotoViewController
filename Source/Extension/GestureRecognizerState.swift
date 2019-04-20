//
//  File.swift
//  PhotoViewController
//
//  Created by Felicity on 8/26/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import Foundation

// function for logging, somehow I cannot log state directly :)
extension GestureRecognizerState {
  var name: String {
    switch self {
    case .began:
      return "began"
    case .possible:
      return "possible"
    case .changed:
      return "changed"
    case .ended:
      return "ended"
    case .cancelled:
      return "cancelled"
    case .failed:
      return "failed"
    @unknown default:
      return "unknown"
    }
  }
}
