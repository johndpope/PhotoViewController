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

  override func updateImmersiveUI(_ state: PhotoImmersiveMode?) {
    super.updateImmersiveUI(state)
    if resource.type ~= .gif {
      let color = (state ?? PhotoViewManager.default.immersiveMode) ~= .normal ? UIColor.white : UIColor.black
      gifView.stopAnimating()
      gifView.backgroundColor = color
      gifView.startAnimating()
    }
  }

}

/// mypage
class MyPagingController<T: IndexPathSearchable>: PhotoPageController<T> {

  override func photoShow(modally: Bool, resource: MediaResource) -> UIViewController {
    return MyPhotoShowController(isModalTransition: modally, resource: resource)
  }

}


/// custom
class CustomPhotoPageController: UIViewController, ImageZoomForceTouchProvider {

  var isForceTouching: Bool = false {
    didSet {
      page?.isForceTouching = isForceTouching
    }
  }

  override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
    self.preferredContentSize = container.preferredContentSize
    super.preferredContentSizeDidChange(forChildContentContainer: container)
  }

  var page: MyPagingController<[MediaResource]>?
  var pageControl: UIPageControl?
  convenience init(modally: Bool, startIndex: IndexPath, resources: [[MediaResource]], navigationOrientation: PageViewControllerNavigationOrientation) {
    self.init(nibName: nil, bundle: nil)
    page = MyPagingController(isModalTransition: modally, startIndexPath: startIndex, resources: resources, navigationOrientation: navigationOrientation)
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
    view?.addSubview(pageControl)
    pageControl.backgroundColor = UIColor.clear
    pageControl.pageIndicatorTintColor = UIColor.lightGray
    pageControl.currentPageIndicatorTintColor = UIColor.darkGray
    pageControl.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    pageControl.translatesAutoresizingMaskIntoConstraints = false
    if #available(iOS 9.0, *) {
      pageControl.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor, constant: -20).isActive = true
      pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
      pageControl.heightAnchor.constraint(equalToConstant: 20).isActive = true
      pageControl.widthAnchor.constraint(equalToConstant: 300).isActive = true
    } else {
      NSLayoutConstraint(item: pageControl, attribute: .bottom, relatedBy: .equal, toItem: bottomLayoutGuide, attribute: .top, multiplier: 1, constant: -20).isActive = true
      NSLayoutConstraint(item: pageControl, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
      NSLayoutConstraint(item: pageControl, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 20).isActive = true
      NSLayoutConstraint(item: pageControl, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 300).isActive = true
      // Fallback on earlier versions
    }
  }


  @available(iOS 9.0, *)
  override var previewActionItems: [UIPreviewActionItem] {
    return [UIPreviewAction(title: "Save to Library", style: .default) { [weak self] (_, controller) in
      self?.page?.currentImage.map {
        UIImageWriteToSavedPhotosAlbum($0, nil, nil, nil)
      }
      controller.dismiss(animated: true, completion: nil)
      }, UIPreviewAction(title: "Delete", style: .destructive) { [weak self] (_, controller) in
        self?.page?.removeCurrentResource()
        controller.dismiss(animated: true, completion: nil)
      }];
  }

}
