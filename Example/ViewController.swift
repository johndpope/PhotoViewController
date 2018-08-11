//
//  ViewController.swift
//  Example
//
//  Created by Felicity on 8/2/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit
import PhotoViewController
import AlamofireImage
import MobileCoreServices
import PhotosUI
import FLAnimatedImage

extension UIView {
  func firstSubview<T>(ofType type: T.Type) -> T? {
    return subviews.compactMap({ $0 as? T }).first
  }
}

let cornerRadius: CGFloat = 10

class ViewController: UITableViewController {

  var selectedIndexP: IndexPath?

  lazy var datum: [[MediaResource]] = {
    var array: [[MediaResource]] = [0, 1].map { _ -> [MediaResource] in
      return (0...10).map({ String(format: "https://raw.githubusercontent.com/onevcat/Kingfisher/master/images/kingfisher-%d.jpg", $0) })
        .map({ urlString in
          return MediaResource(setImageBlock: { imageView in
            imageView?.af_setImage(withURL: URL(string: urlString)!)
          })
        })
      // "https://raw.githubusercontent.com/onevcat/Kingfisher/master/images/kingfisher-0.jpg" is for testing HTTP-404 not found
    }
    return array
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.reloadData()
    NotificationCenter.default.addObserver(forName: NSNotification.Name.configDidUpdate, object: nil, queue: nil) { _ in
      self.tableView.reloadData()
    }
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Setting", style: UIBarButtonItem.Style.plain, target: self, action: #selector(gotoSetting))
    navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Photos", style: UIBarButtonItem.Style.plain, target: self, action: #selector(gotoPicker))
    navigationController?.delegate = self
  }

  @objc func gotoPicker() -> Void {
    PHPhotoLibrary.requestAuthorization { _ in }
    let p = UIImagePickerController(nibName: nil, bundle: nil)
    if #available(iOS 9.1, *) {
      p.mediaTypes = [kUTTypeLivePhoto as String, kUTTypeImage as String]
    } else {
      // Fallback on earlier versions
    }
    p.delegate = self
    navigationController?.present(p, animated: true, completion: nil)
  }

  @objc func gotoSetting() -> Void {
    navigationController?.pushViewController(UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "setting"), animated: true)
  }

  deinit {
    navigationController?.delegate = nil
  }


  override func numberOfSections(in tableView: UITableView) -> Int {
    return datum.count
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return datum[section].count
  }

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 80
  }

  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 40
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return "\(section)"
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    cell.selectionStyle = .none
    let imageView = cell.contentView.firstSubview(ofType: UIImageView.self)
    cell.contentView.firstSubview(ofType: UILabel.self)?.text = "\(indexPath)"
    imageView?.contentMode = imageContentMode
    imageView?.image = nil
    imageView?.layer.cornerRadius = cornerRadius
    imageView?.clipsToBounds = true
    let resource = datum[indexPath.section][indexPath.row]
    switch resource.type {
    case .image:
      resource.display(inImageView: imageView)
    case .livePhoto:
      if #available(iOS 9.1, *) {
        resource.displayLivePhoto(inLivePhotView: nil, inImageView: imageView)
      }
    case .gif:
      _ = resource.retrieving(.custom(nil, imageView))
    default:
      break
    }
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
    selectedIndexP = indexPath
    PhotoViewManager.default.defaultImmersingState = defaultState
    PhotoViewManager.default.viewTapAction = viewTapAction
    let customPage = CustomPhotoPageController(modally: modally, startIndex: indexPath, resources: datum)
    customPage.page!.loop = pageLoop
    customPage.transitioningDelegate = self
    customPage.modalPresentationStyle = .custom
    let deleteBlock: (inout [[MediaResource]], IndexPath) -> MediaResource = { (collection, idxPath) in
      collection[idxPath.section].remove(at: idxPath.row)
    }
    customPage.page!.resourcesDeleteHandler = deleteBlock
    customPage.page!.didScrollToPage = { [weak customPage, weak self] idxPath in
      guard let strongself = self else { return }
      customPage?.pageControl?.numberOfPages = strongself.datum[idxPath.section].count
      customPage?.pageControl?.currentPage = idxPath.row
    }
    customPage.page!.resourcesDeleteDidCompleteBlock = { [weak self] idxPath, _ in
      guard let strongself = self else { return }
      _ = deleteBlock(&strongself.datum, idxPath)
      strongself.tableView.reloadData()
    }
    if modally {
      navigationController?.present(customPage, animated: true, completion: nil)
    } else {
      navigationController?.pushViewController(customPage, animated: true)
    }
  }

}

// MARK: - config
extension ViewController {

  var viewTapAction: PhotoViewTapAction {
    return ExampleConfigManager.shared.viewTap.currentValue as! PhotoViewTapAction
  }

  var defaultState: PhotoImmersingState {
    return ExampleConfigManager.shared.defaultState.currentValue as! PhotoImmersingState
  }

  var modally: Bool {
    return ExampleConfigManager.shared.transitionModally.currentValue as! Bool
  }

  var dismissInterval: TimeInterval {
    return ExampleConfigManager.shared.dimissTimeInterval.currentValue as! TimeInterval
  }

  var showingInterval: TimeInterval {
    return ExampleConfigManager.shared.showingTimeInterval.currentValue as! TimeInterval
  }

  var pageLoop: Bool {
    return ExampleConfigManager.shared.pageLoop.currentValue as! Bool
  }

  var iOS10APIEnabled: Bool {
    return ExampleConfigManager.shared.iOS10Only.currentValue as! Bool
  }

  var iOS10Spring: Bool {
    return ExampleConfigManager.shared.iOS10Spring.currentValue as! Bool
  }

  var showSpringDamping: CGFloat {
    return ExampleConfigManager.shared.showSpringDamping.currentValue as! CGFloat
  }

  var dismissSpringDamping: CGFloat {
    return ExampleConfigManager.shared.dismissSpringDamping.currentValue as! CGFloat
  }

  var showCurve: UIView.AnimationOptions {
    return ExampleConfigManager.shared.showCurve.currentValue as! UIView.AnimationOptions
  }

  var dismissCurve: UIView.AnimationOptions {
    return ExampleConfigManager.shared.dismissCurve.currentValue as! UIView.AnimationOptions
  }

  var imageContentMode: UIView.ContentMode {
    return ExampleConfigManager.shared.imageContentMode.currentValue as! UIView.ContentMode
  }

  func curve(_ option: UIView.AnimationOptions) -> UIView.AnimationCurve {
    if option.contains(.curveEaseInOut) {
      return .easeInOut
    } else if option.contains(.curveEaseIn) {
      return .easeIn
    } else if option.contains(.curveEaseOut) {
      return .easeOut
    } else if option.contains(.curveLinear) {
      return .linear
    } else {
      fatalError("wrong option")
    }
  }

  func animationOption(forShowing showing: Bool) -> ImageZoomAnimationOption {
    let damping = showing ? showSpringDamping : dismissSpringDamping
    let animationCurve = showing ? showCurve : dismissCurve
    if iOS10APIEnabled {
      if #available(iOS 10.0, *) {
        if iOS10Spring {
          return .perferred({
            UIViewPropertyAnimator(duration: $0, dampingRatio: damping , animations: nil)
          })
        } else {
          let curve = self.curve(animationCurve)
          return .perferred({
            UIViewPropertyAnimator(duration: $0, curve: curve, animations: nil)
          })
        }
      } else {
        fatalError("You should never select this on old OS")
      }
    } else {
      return .fallback(springDampingRatio: damping, initialSpringVelocity: 1, options: animationCurve)
    }
  }
}


// MARK: - custom transition
extension ViewController {

  func transitionTo(showing viewController: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    guard let selectedIndexP = selectedIndexP else { return nil }
    guard let cell = tableView.cellForRow(at: selectedIndexP) else { return nil }
    guard let imageView = cell.contentView.firstSubview(ofType: UIImageView.self) else { return nil }
    guard let viewController = viewController as? CustomPhotoPageController else { return nil }
    let image = imageView.image

    let t = ZoomInAnimatedTransitioning(duration: showingInterval,
                                       option: animationOption(forShowing: true),
                                       animator: ImageZoomAnimator.showFromImageView(imageView, image: image, provider: viewController.page!),
                                       animationWillBegin: {
                                        imageView.isHidden = true },
                                       animationDidFinish: { _ in
                                        imageView.isHidden = false })
    t.prepareAnimation = { imageView in
      imageView.clipsToBounds = true
      imageView.layer.cornerRadius = cornerRadius
    }
    t.userAnimation = { _, imageView in
      //FIXME: cornerRadius = 0, flick the screen, when using local photo on iOS 11
      // imageView.layer.cornerRadius = 0
      imageView.layer.cornerRadius = 1
    }
    return t
  }

  func transitionFrom(dismissed viewController: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    guard let viewController = viewController as? CustomPhotoPageController else { return nil }
    let selectedIndexP = viewController.page!.userCurrentIndexPath
    tableView.scrollToRow(at: selectedIndexP, at: .none, animated: false)
    guard let cell = tableView.cellForRow(at: selectedIndexP) else { return nil }
    guard let imageView = cell.contentView.firstSubview(ofType: UIImageView.self) else { return nil }

    let t = ZoomOutAnimatedTransitioning(duration: dismissInterval,
                                        option: animationOption(forShowing: false),
                                        animator: ImageZoomAnimator.dismissToImageView(imageView, provider: viewController.page!),
                                        animationWillBegin: {
                                          imageView.isHidden = true },
                                        animationDidFinish: { _ in
                                          imageView.isHidden = false })
    t.prepareAnimation = { imageView in
      imageView.clipsToBounds = true
      imageView.layer.cornerRadius = 0
    }
    t.userAnimation = { interactive, cancelled, imageView in
      if !interactive {
        imageView.layer.cornerRadius = cancelled ? 0 : cornerRadius
      }
    }
    return t
  }

}


// MARK: - present modal
extension ViewController: UIViewControllerTransitioningDelegate {

  func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return transitionTo(showing: presented)
  }

  func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return transitionFrom(dismissed:dismissed)
  }

  func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    return (animator as? ZoomOutAnimatedTransitioning)?.interactiveTransitioning
  }

}


// MARK: - navigation push
extension ViewController: UINavigationControllerDelegate {

  func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    switch operation {
    case .push:
      return transitionTo(showing: toVC)
    case .pop:
      return transitionFrom(dismissed: fromVC)
    case .none:
      return nil
    }
  }

  func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    return (animationController as? ZoomOutAnimatedTransitioning)?.interactiveTransitioning
  }

}



// MARK: - pick photo
extension ViewController: UIImagePickerControllerDelegate {
  @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }

  @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    defer {
      tableView.reloadData()
      picker.dismiss(animated: true, completion: nil)
    }
    var handled: Bool = false
    if let type = info[.mediaType] as? String {
      if #available(iOS 9.1, *) {
        if type == kUTTypeLivePhoto as String {
          handled = true
          var __asset: PHAsset?
          if let live = info[.livePhoto] as? PHLivePhoto {
            var size: CGSize = .zero
            if live.size.isValid {
              size = live.size
            } else {
              if #available(iOS 11.0, *) {
                if let asset = info[.phAsset] as? PHAsset, CGSize(width: asset.pixelWidth, height: asset.pixelHeight).isValid {
                  size = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                  __asset = asset
                }
              }
            }
            datum[0].append(MediaResource(setLivePhotoBlock: { (photoView, imageView) in
              __asset?.loadImage(completion: { (image) in
                imageView?.image = image
              })
              photoView?.livePhoto = live
              return size
            }))
          }
        }
      }

      if !handled {
        if type == kUTTypeImage as String {
          if #available(iOS 11.0, *) {

            /// referenceURL is deprecated, for demo only
            if let url = info[.referenceURL] as? URL, url.absoluteString.uppercased().contains("GIF"), let asset = info[.phAsset] as? PHAsset {
              datum[0].append(MediaResource(type: .gif, identifier: UUID().uuidString, retrieving: {
                switch $0 {
                case let .custom(gifView, imageView):
                  PHImageManager.default().requestImageData(for: asset, options: nil, resultHandler: { (data, _, _, _) in
                    let fl = FLAnimatedImage(gifData: data!)!
                    imageView?.image = fl.posterImage
                    if let gifView = gifView as? FLAnimatedImageView {
                      gifView.animatedImage = fl
                    }
                  })
                default:
                  break
                }
                return nil
              }))
              return
            }

            if let asset = info[.phAsset] as? PHAsset {
              datum[0].append(MediaResource(setImageBlock: { (imageView) in
                asset.loadImage(completion: { (image) in
                  imageView?.image = image
                })
              }))
              return
            }

          }

          if let edited = info[.editedImage] as? UIImage {
            datum[0].append(MediaResource(setImageBlock: { (imageView) in
              imageView?.image = edited
            }))
          } else if let original = info[.originalImage] as? UIImage {
            datum[0].append(MediaResource(setImageBlock: { (imageView) in
              imageView?.image = original
            }))
          }
        }
      }
    }
  }
}

extension PHAsset {
  func loadImage(size: CGSize = CGSize(width: 500, height: 500), completion: @escaping (UIImage?) -> Void) -> Void {
    PHImageManager.default().requestImage(for: self, targetSize: size, contentMode: .aspectFit, options: nil) { (image, info) in
      var isDegraded: Bool = false
      if let down = info?[PHImageResultIsDegradedKey] as? Bool, down {
        isDegraded = true
      }
      if !isDegraded {
        DispatchQueue.main.async {
          completion(image)
        }
      }
    }
  }
}
