//
//  CustomPhotoPageController.swift
//  Example
//
//  Created by Felicity on 8/7/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit
import PhotoViewController
import FLAnimatedImage


/// myshow
class MyPhotoShowController: PhotoShowController {
  lazy var gifView: FLAnimatedImageView = FLAnimatedImageView(frame: .zero)

  override func configGIFImageView() {
    imageView.addSubview(gifView)
  }

  override var gifResourceContentSize: CGSize? {
    return imageView.image?.size
  }

  override func recalibrateGIFImageViewFrame() {
    guard let resourceContentSize = resourceContentSize else { return }
    recalibrateContentViewFrame(resourceSize: resourceContentSize)
    gifView.frame = imageView.bounds
  }

  override func loadGIFResource() {
    _ = resource.retrieving(.custom(gifView, imageView))
  }


  override func addGIFImageObserver() {
    imageView.addObserver(self, forKeyPath: #keyPath(UIImageView.image), options: [.new], context: nil)
  }

  override func removeGIFImageObserver() {
    imageView.removeObserver(self, forKeyPath: #keyPath(UIImageView.image))
  }

  override func observeGIFImageSize(forKeyPath keyPath: String?) -> Bool {
    if keyPath == #keyPath(UIImageView.image) {
      return true
    }
    return false
  }

}

/// mypage
class MyPagingController<T: IndexPathSearchable>: PhotoPageController<T> {
  override func photoShow(modally: Bool, resource: MediaResource) -> UIViewController {
    return MyPhotoShowController(modally: modally, resource: resource)
  }
}


/// custom
class CustomPhotoPageController: UIViewController {
  var page: MyPagingController<[MediaResource]>?
  var pageControl: UIPageControl?
  convenience init(modally: Bool, startIndex: IndexPath, resources: [[MediaResource]]) {
    self.init(nibName: nil, bundle: nil)
    page = MyPagingController(modally: modally, startIndexPath: startIndex, resources: resources)
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
    if #available(iOS 9.0, *) {
      pageControl.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20).isActive = true
      pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
      pageControl.heightAnchor.constraint(equalToConstant: 20).isActive = true
      pageControl.widthAnchor.constraint(equalToConstant: 300).isActive = true
    } else {
      // Fallback on earlier versions
    }
  }

}
