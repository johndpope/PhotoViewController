//
//  Config.swift
//  Example
//
//  Created by Felicity on 8/7/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit
import PhotoViewController

extension Notification.Name {
  static var configDidUpdate: Notification.Name {
    return Notification.Name("PhotoViewConfigDidUpdate")
  }
}

class ExampleConfigWrapper {
  var name: String
  var availables: [Any]
  var selectedIndex: Int = 0 {
    didSet {
      NotificationCenter.default.post(name: NSNotification.Name.configDidUpdate, object: nil)
    }
  }
  var currentValue: Any {
    return availables[selectedIndex]
  }
  private var availableStrings__: [String]?
  var availableStrings: [String] {
    return availableStrings__ ?? availables.map({ String(describing: $0) })
  }
  init(name: String, availables: [Any], availableStrings: [String]? = nil) {
    self.name = name
    self.availables = availables
    self.availableStrings__ = availableStrings
  }
}

class ExampleConfigManager {
  static let shared: ExampleConfigManager = ExampleConfigManager()
  lazy var list: [ExampleConfigWrapper] = [transitionModally,
                                           pageLoop,
                                           imageContentMode,
                                           showingTimeInterval,
                                           dimissTimeInterval,
                                           showSpringDamping,
                                           dismissSpringDamping,
                                           showCurve,
                                           dismissCurve,
                                           viewTap,
                                           defaultState,
                                           iOS10Only,
                                           iOS10Spring,
                                           ]
  var imageContentMode: ExampleConfigWrapper = ExampleConfigWrapper(name: "fromImageContentMode", availables: [.scaleToFill, .scaleAspectFit, .scaleAspectFill] as [UIView.ContentMode], availableStrings: ["Fill", "AspectFit", "AspectFill"])
  var pageLoop: ExampleConfigWrapper = ExampleConfigWrapper(name: "pageLoop", availables: [false, true])
  var transitionModally: ExampleConfigWrapper = ExampleConfigWrapper(name: "transitionModally", availables: [false, true])
  var showingTimeInterval: ExampleConfigWrapper = ExampleConfigWrapper(name: "showingTimeInterval", availables: [0.5, 1, 2, 3, 0.1, 0.2, 0.3] as [TimeInterval])
  var dimissTimeInterval: ExampleConfigWrapper = ExampleConfigWrapper(name: "dimissTimeInterval", availables: [0.5, 1, 2, 3, 0.1, 0.2, 0.3] as [TimeInterval])
  var showSpringDamping: ExampleConfigWrapper = ExampleConfigWrapper(name: "showSpringDamping", availables: [0.7, 0.6, 0.5, 0.8, 0.9, 1] as [CGFloat])
  var dismissSpringDamping: ExampleConfigWrapper = ExampleConfigWrapper(name: "dismissSpringDamping", availables: [0.7, 0.6, 0.5, 0.8, 0.9, 1] as [CGFloat])
  var showCurve: ExampleConfigWrapper = ExampleConfigWrapper(name: "showCurve", availables: [.curveEaseInOut, .curveEaseIn, .curveEaseOut, .curveLinear] as [UIView.AnimationOptions], availableStrings: ["EaseInOut", "EaseIn", "EaseOut", "Linear"])
  var dismissCurve: ExampleConfigWrapper = ExampleConfigWrapper(name: "dismissCurve", availables: [.curveEaseInOut, .curveEaseIn, .curveEaseOut, .curveLinear] as [UIView.AnimationOptions], availableStrings: ["EaseInOut", "EaseIn", "EaseOut", "Linear"])
  var iOS10Only: ExampleConfigWrapper = ExampleConfigWrapper(name: "iOS10+ Only", availables: [false, true])
  var iOS10Spring: ExampleConfigWrapper = ExampleConfigWrapper(name: "iOS10+ Spring", availables: [false, true])
  var viewTap: ExampleConfigWrapper = ExampleConfigWrapper(name: "viewTap", availables: [.toggleImmersingState, .dismiss] as [PhotoViewTapAction])
  var defaultState: ExampleConfigWrapper = ExampleConfigWrapper(name: "defaultState", availables: [.normal, .immersed] as [PhotoImmersingState])

}

