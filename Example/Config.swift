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
                                           scrollDirection,
                                           panDirection,
                                           panScale,
                                           iOS10Only,
                                           iOS10Spring,
                                           ]
  var imageContentMode: ExampleConfigWrapper = ExampleConfigWrapper(name: "fromImageContentMode", availables: [.scaleToFill, .scaleAspectFit, .scaleAspectFill] as [ViewContentMode], availableStrings: ["Fill", "AspectFit", "AspectFill"])
  var pageLoop: ExampleConfigWrapper = ExampleConfigWrapper(name: "pageLoop", availables: [false, true])
  var transitionModally: ExampleConfigWrapper = ExampleConfigWrapper(name: "transitionModally", availables: [false, true])
  var scrollDirection: ExampleConfigWrapper = ExampleConfigWrapper(name: "scrollDirection", availables: [.horizontal, .vertical] as [PageViewControllerNavigationOrientation], availableStrings: ["horizontal", "vertical"])
  var panDirection: ExampleConfigWrapper = ExampleConfigWrapper(name: "panDirection", availables: [.bottom, .left, .all, .none] as [PhotoViewDismissDirection], availableStrings: ["bottom", "left", "all", "none"])
  var panScale: ExampleConfigWrapper = ExampleConfigWrapper(name: "panScale", availables: [0.3, 0.5, 0.9, 1.1] as [CGFloat])
  var showingTimeInterval: ExampleConfigWrapper = ExampleConfigWrapper(name: "showingTimeInterval", availables: [0.5, 1, 2, 3, 0.1, 0.2, 0.3] as [TimeInterval])
  var dimissTimeInterval: ExampleConfigWrapper = ExampleConfigWrapper(name: "dimissTimeInterval", availables: [0.5, 1, 2, 3, 0.1, 0.2, 0.3] as [TimeInterval])
  var showSpringDamping: ExampleConfigWrapper = ExampleConfigWrapper(name: "showSpringDamping", availables: [0.7, 0.6, 0.5, 0.8, 0.9, 1] as [CGFloat])
  var dismissSpringDamping: ExampleConfigWrapper = ExampleConfigWrapper(name: "dismissSpringDamping", availables: [0.7, 0.6, 0.5, 0.8, 0.9, 1] as [CGFloat])
  var showCurve: ExampleConfigWrapper = ExampleConfigWrapper(name: "showCurve", availables: [.curveEaseInOut, .curveEaseIn, .curveEaseOut, .curveLinear] as [ViewAnimationOptions], availableStrings: ["EaseInOut", "EaseIn", "EaseOut", "Linear"])
  var dismissCurve: ExampleConfigWrapper = ExampleConfigWrapper(name: "dismissCurve", availables: [.curveEaseInOut, .curveEaseIn, .curveEaseOut, .curveLinear] as [ViewAnimationOptions], availableStrings: ["EaseInOut", "EaseIn", "EaseOut", "Linear"])
  var iOS10Only: ExampleConfigWrapper = ExampleConfigWrapper(name: "iOS10+ Only", availables: [false, true])
  var iOS10Spring: ExampleConfigWrapper = ExampleConfigWrapper(name: "iOS10+ Spring", availables: [false, true])

}

