//
//  CustomPhotoPageController.swift
//  Example
//
//  Created by Felicity on 8/7/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit
import PhotoViewController

class CustomPhotoPageController: UIViewController {
  var page: PhotoPageController<[MediaResource]>?
  var pageControl: UIPageControl?
  convenience init(modally: Bool, startIndex: IndexPath, resources: [[MediaResource]]) {
    self.init(nibName: nil, bundle: nil)
    page = PhotoPageController(modally: modally, startIndexPath: startIndex, resources: resources)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    addPageControl()
    page?.embed(in: self)
    view.insertSubview(page!.view, at: 0)
    page?.view.frame = view.bounds
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Delete", style: .plain, target: self, action: #selector(deleteCurrentPhoto))
  }

  @objc func deleteCurrentPhoto() -> Void {
    page?.removeCurrentResource()
  }

  override var prefersStatusBarHidden: Bool {
    return page!.prefersStatusBarHidden
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return page!.preferredStatusBarStyle
  }

  func addPageControl() -> Void {
    let pageControl = UIPageControl(frame: .zero)
    self.pageControl = pageControl
    view.addSubview(pageControl)
    pageControl.pageIndicatorTintColor = UIColor.lightGray
    pageControl.currentPageIndicatorTintColor = UIColor.darkGray
    pageControl.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    pageControl.translatesAutoresizingMaskIntoConstraints = false
    pageControl.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20).isActive = true
    pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    pageControl.heightAnchor.constraint(equalToConstant: 20).isActive = true
    pageControl.widthAnchor.constraint(equalToConstant: 300).isActive = true
  }

}
