//
//  ViewController.swift
//  Example
//
//  Created by Felicity on 8/2/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit
import PhotoViewController
import MobileCoreServices
import PhotosUI
import FLAnimatedImage

extension UIView {
  func firstSubview<T>(ofType type: T.Type) -> T? {
    return subviews.compactMap({ $0 as? T }).first
  }
}

let cornerRadius: CGFloat = 10

class ViewController: UITableViewController, PhotoPageControllerDelegate {

  var selectedIndexP: IndexPath?

  var cache: NSCache = NSCache<NSString, UIImage>()

  lazy var datum: [[MediaResource]] = {
    var array: [[MediaResource]] = [0, 1].map { _ -> [MediaResource] in
      return (0...10).map({ String(format: "https://raw.githubusercontent.com/onevcat/Kingfisher/master/images/kingfisher-%d.jpg", $0) })
        .map({ urlString in
          return MediaResource(setImageBlock: { imageView in
            if let cacheImage = self.cache.object(forKey: urlString as NSString) {
              imageView?.image = cacheImage
              return
            }
            imageView?.image = UIImage(named: "placeholder")
            URLSession.shared.dataTask(with: URL(string: urlString)!, completionHandler: { (_data, _resp, _error) in
              guard let data = _data else {
                return
              }
              if let image = UIImage(data: data) {
                self.cache.setObject(image, forKey: urlString as NSString)
                DispatchQueue.main.async {
                  imageView?.image = image
                }
              }
            }).resume()
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
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Setting", style: .plain, target: self, action: #selector(gotoSetting))
    navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Photos", style: .plain, target: self, action: #selector(gotoPicker))
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
    imageView?.isUserInteractionEnabled = true
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

  override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    if #available(iOS 9.0, *) {
      if traitCollection.forceTouchCapability == .available {
        if let imageView = cell.contentView.firstSubview(ofType: UIImageView.self) {
          registerForPreviewing(with: self, sourceView: imageView)
        }
      }
    }
  }

  func showController(at indexPath: IndexPath, previewing: Bool) -> CustomPhotoPageController? {
    selectedIndexP = indexPath
    let customPage = CustomPhotoPageController(modally: modally, navigationOrientation: scrollDirection)
    customPage.page?.resources = datum
    customPage.page?.userStartIndexPath = indexPath
    customPage.page?.loop = pageLoop
    customPage.page?.delegate = self
    let configuration = customPage.page!.configuration
    configuration.defaultImmersiveMode = defaultState
    configuration.viewTapAction = viewTapAction
    configuration.interactiveDismissDirection = panDirection
    configuration.interactiveDismissScaleFactor = panScale
    if previewing {
      let cell = tableView.cellForRow(at: indexPath)!
      configuration.hintImage = cell.contentView.firstSubview(ofType: UIImageView.self)?.image
    }
    customPage.view.alpha = 1
    customPage.isForceTouching = previewing
    customPage.hidesBottomBarWhenPushed = true
    return customPage
  }
  
  func removeUserResource<T>(controller: PhotoPageController<T>, at indexPath: IndexPath, completion: @escaping (Bool) -> Void) where T : IndexPathSearchable {
    let alertController = UIAlertController(title: nil, message: "This action can not be undone", preferredStyle: .alert)
    let delete = UIAlertAction(title: "Delete", style: .destructive, handler: { (action) in
      let success = true
      if success {
        self.datum.removeItemAt(indexPath: indexPath)
        self.tableView.reloadData()
      }
      completion(success)
    })
    alertController.addAction(delete)
    let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
      completion(false)
    })
    alertController.addAction(cancel)
    UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
  }
  
  func pageDidScroll<T>(controller: PhotoPageController<T>, to indexPath: IndexPath) where T : IndexPathSearchable {
    guard let customPage = controller.parent as? CustomPhotoPageController  else { return }
    customPage.pageControl?.numberOfPages = self.datum[indexPath.section].count
    customPage.pageControl?.currentPage = indexPath.row
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
    let customPage = showController(at: indexPath, previewing: false)!
    prepareForZoomTransitioning(pageController: customPage,
                                transferrer: self,
                                transitioningDelegate: transitionProvider,
                                modal: modally)
    if modally {
      navigationController?.present(customPage, animated: true, completion: nil)
    } else {
      navigationController?.pushViewController(customPage, animated: true)
    }
  }

  lazy var transitionProvider = ZoomAnimatedTransitioningController(delegate: self)

  var transferResult: UINavigationControllerDelegateTransferResult?
}

enum UINavigationControllerDelegateTransferResult {
  case noViewController
  case delegate(UINavigationControllerDelegate?)
}

extension UINavigationController {
  open override var childForStatusBarStyle: UIViewController? {
    return topViewController
  }
}

extension ViewController: UIViewControllerPreviewingDelegate {

  @available(iOS 9.0, *)
  func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
    if let cell = previewingContext.sourceView.superview?.superview as? UITableViewCell, let indexPath = tableView.indexPath(for: cell) {
      return showController(at: indexPath, previewing: true)
    }
    return nil
  }

  @available(iOS 9.0, *)
  func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
    (viewControllerToCommit as? ImageZoomForceTouchProvider)?.isForceTouching = false
    prepareForZoomTransitioning(pageController: viewControllerToCommit,
                                transferrer: self,
                                transitioningDelegate: transitionProvider,
                                modal: modally)
    if modally {
      navigationController?.present(viewControllerToCommit, animated: true, completion: nil)
    } else {
      navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
  }

}

// MARK: - config
extension ViewController {

  var viewTapAction: PhotoViewTapAction {
    return ExampleConfigManager.shared.viewTap.currentValue as! PhotoViewTapAction
  }

  var defaultState: PhotoImmersiveMode {
    return ExampleConfigManager.shared.defaultState.currentValue as! PhotoImmersiveMode
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

  var showCurve: ViewAnimationOptions {
    return ExampleConfigManager.shared.showCurve.currentValue as! ViewAnimationOptions
  }

  var dismissCurve: ViewAnimationOptions {
    return ExampleConfigManager.shared.dismissCurve.currentValue as! ViewAnimationOptions
  }

  var panScale: CGFloat {
    return ExampleConfigManager.shared.panScale.currentValue as! CGFloat
  }

  var panDirection: PhotoViewDismissDirection {
    return ExampleConfigManager.shared.panDirection.currentValue as! PhotoViewDismissDirection
  }

  var scrollDirection: PageViewControllerNavigationOrientation {
    return ExampleConfigManager.shared.scrollDirection.currentValue as! PageViewControllerNavigationOrientation
  }

  var imageContentMode: ViewContentMode {
    return ExampleConfigManager.shared.imageContentMode.currentValue as! ViewContentMode
  }

  func curve(_ option: ViewAnimationOptions) -> ViewAnimationCurve {
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

extension ViewController: UINavigationControllerDelegateTransferrer {

  func transferDelegate(for controller: UINavigationController?) {
    guard let controller = controller else {
      self.transferResult = .noViewController
      return
    }
    self.transferResult = .delegate(controller.delegate)
  }

  func restoreNavigationControllerDelegate() {
    switch self.transferResult {
    case .some(.delegate(let delegate)):
      self.navigationController?.delegate = delegate
    default:
      break
    }
  }
}

// MARK: - custom transition
extension ViewController {

  func currentImageView(direction: ZoomAnimatedTransitioningDirection, viewController: UIViewController) -> UIImageView? {
    switch direction {
    case .incoming:
      guard let selectedIndexP = selectedIndexP else { return nil }
      guard let cell = tableView.cellForRow(at: selectedIndexP) else { return nil }
      guard let imageView = cell.contentView.firstSubview(ofType: UIImageView.self) else { return nil }
      return imageView
    case .outgoing:
      guard let viewController = viewController as? CustomPhotoPageController else { return nil }
      let selectedIndexP = viewController.page!.userCurrentIndexPath
      guard tableView.numberOfSections > selectedIndexP.section && tableView.numberOfRows(inSection: selectedIndexP.section) > selectedIndexP.row  else {
        return nil
      }
      tableView.scrollToRow(at: selectedIndexP, at: .none, animated: false)
      guard let cell = tableView.cellForRow(at: selectedIndexP) else { return nil }
      guard let imageView = cell.contentView.firstSubview(ofType: UIImageView.self) else { return nil }
      return imageView
    }
  }

  func photoZoomInTransition(incoming viewController: UIViewController) -> ZoomInAnimatedTransitioning? {
    guard let viewController = viewController as? CustomPhotoPageController else { return nil }
    guard let imageView = currentImageView(direction: .incoming, viewController: viewController) else { return nil }
    let t = ZoomInAnimatedTransitioning(duration: showingInterval,
                                        option: animationOption(forShowing: true),
                                        provider: ZoomInAnimatedTransitioningProvider(source: SmallPhotoViewProvider(imageView: imageView, image: imageView.image),
                                                                                      destionation: viewController.page!))
    t.delegate = self
    return t
  }

  func photoZoomOutTransition(outgoing viewController: UIViewController) -> ZoomOutAnimatedTransitioning? {
    guard let viewController = viewController as? CustomPhotoPageController else { return nil }
    guard let imageView = currentImageView(direction: .outgoing, viewController: viewController) else { return nil }
    let t = ZoomOutAnimatedTransitioning(duration: dismissInterval,
                                         option: animationOption(forShowing: false),
                                         provider: ZoomOutAnimatedTransitioningProvider(source: viewController.page!,
                                                                                        destionation: SmallPhotoViewProvider(imageView: imageView, image: nil)))
    t.delegate = self
    t.transferrer = self
    return t
  }

}

extension ViewController: ZoomAnimatedTransitioningDelegate {

  func zoomTransition(direction: ZoomAnimatedTransitioningDirection, viewController: UIViewController) -> ZoomAnimatedTransitioning? {
    switch direction {
    case .incoming:
      return self.photoZoomInTransition(incoming: viewController)
    case .outgoing:
      return self.photoZoomOutTransition(outgoing: viewController)
    }
  }

  func transitionWillBegin(transitionAnimator: ZoomAnimatedTransitioning, transitionContext: UIViewControllerContextTransitioning) {
    switch transitionAnimator.direction {
    case .incoming:
      guard let viewController = transitionContext.viewController(forKey: .to) else { return }
      guard let imageView = currentImageView(direction: transitionAnimator.direction, viewController: viewController) else { return }
      imageView.isHidden = true
    case .outgoing:
      guard let viewController = transitionContext.viewController(forKey: .from) else { return }
      guard let imageView = currentImageView(direction: transitionAnimator.direction, viewController: viewController) else { return }
      imageView.isHidden = true
    }
  }

  func transitionDidFinish(transitionAnimator: ZoomAnimatedTransitioning, finished: Bool) {
    switch transitionAnimator.direction {
    case .incoming:
      break
    case .outgoing:
      break
    }
  }

  func transitionWillBeginAnimation(transitionAnimator: ZoomAnimatedTransitioning, transitionContext: UIViewControllerContextTransitioning, imageView: UIImageView) {
    switch transitionAnimator.direction {
    case .incoming:
      imageView.clipsToBounds = true
      imageView.layer.cornerRadius = cornerRadius
      guard let viewController = transitionContext.viewController(forKey: .to) else { return }
      viewController.view.alpha = 0
    case .outgoing:
      imageView.clipsToBounds = true
      imageView.layer.cornerRadius = 0
    }
  }

  func transitionDidFinishAnimation(transitionAnimator: ZoomAnimatedTransitioning, transitionContext: UIViewControllerContextTransitioning, finished: Bool) {
    switch transitionAnimator.direction {
    case .incoming:
      guard let viewController = transitionContext.viewController(forKey: .to) else { return }
      viewController.view.alpha = 1
      guard let imageView = currentImageView(direction: transitionAnimator.direction, viewController: viewController) else { return }
      imageView.isHidden = false
    case .outgoing:
      guard let viewController = transitionContext.viewController(forKey: .from) else { return }
      viewController.view.alpha = 1
      guard let imageView = currentImageView(direction: transitionAnimator.direction, viewController: viewController) else { return }
      imageView.isHidden = false
    }
  }

  func transitionUserAnimation(transitionAnimator: ZoomAnimatedTransitioning?, transitionContext: UIViewControllerContextTransitioning?, isInteractive: Bool, isCancelled: Bool, progress: CGFloat?, imageView: UIImageView) {
    guard let transition = transitionAnimator else { return }
    switch transition.direction {
    case .incoming:
      imageView.clipsToBounds = true
      imageView.layer.cornerRadius = 0
      guard let viewController = transitionContext?.viewController(forKey: .to) else { return }
      viewController.view.alpha = progress ?? 1
    case .outgoing:
      let progress = progress ?? 1
      imageView.clipsToBounds = true
      imageView.layer.cornerRadius = progress * cornerRadius
      guard let viewController = transitionContext?.viewController(forKey: .from) else { return }
      viewController.view.alpha = 1 - progress
    }
  }
}

// MARK: - pick photo
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

  #if swift(>=4.2)
  typealias ImagePickerControllerInfoKey = UIImagePickerController.InfoKey
  var imagePickerControllerMediaType: ImagePickerControllerInfoKey {
    return .mediaType
  }
  var imagePickerControllerOriginalImage: ImagePickerControllerInfoKey {
    return .originalImage
  }
  var imagePickerControllerEditedImage: ImagePickerControllerInfoKey {
    return .editedImage
  }
  var imagePickerControllerReferenceURL: ImagePickerControllerInfoKey {
    return .referenceURL
  }
  @available(iOS 9.1, *)
  var imagePickerControllerLivePhoto: ImagePickerControllerInfoKey {
    return .livePhoto
  }
  @available(iOS 11.0, *)
  var imagePickerControllerPHAsset: ImagePickerControllerInfoKey {
    return .phAsset
  }
  #else
  typealias ImagePickerControllerInfoKey = String
  var imagePickerControllerMediaType: ImagePickerControllerInfoKey {
    return UIImagePickerControllerMediaType
  }
  var imagePickerControllerOriginalImage: ImagePickerControllerInfoKey {
    return UIImagePickerControllerOriginalImage
  }
  var imagePickerControllerEditedImage: ImagePickerControllerInfoKey {
    return UIImagePickerControllerEditedImage
  }
  var imagePickerControllerReferenceURL: ImagePickerControllerInfoKey {
    return UIImagePickerControllerReferenceURL
  }
  @available(iOS 9.1, *)
  var imagePickerControllerLivePhoto: ImagePickerControllerInfoKey {
    return UIImagePickerControllerLivePhoto
  }
  @available(iOS 11.0, *)
  var imagePickerControllerPHAsset: ImagePickerControllerInfoKey {
    return UIImagePickerControllerPHAsset
  }
  #endif
  @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }

  @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [ImagePickerControllerInfoKey : Any]) {
    defer {
      tableView.reloadData()
      picker.dismiss(animated: true, completion: nil)
    }
    let type = info[imagePickerControllerMediaType] as? String
    let url = info[imagePickerControllerReferenceURL] as? URL
    let edited = info[imagePickerControllerEditedImage] as? UIImage
    let original = info[imagePickerControllerOriginalImage] as? UIImage
    var livePhoto: Any?
    var asset: PHAsset?
    if #available(iOS 9.1, *) {
      livePhoto = info[imagePickerControllerLivePhoto]
    }

    if #available(iOS 11.0, *) {
      asset = info[imagePickerControllerPHAsset] as? PHAsset
      /// referenceURL is deprecated, for demo only
    }

    if #available(iOS 9.1, *) {
      if let livePhoto = livePhoto as? PHLivePhoto {
        var size: CGSize = .zero
        if livePhoto.size.isValid {
          size = livePhoto.size
        } else {
          if let asset = asset, CGSize(width: asset.pixelWidth, height: asset.pixelHeight).isValid {
            size = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
          }
        }
        datum[0].append(MediaResource(setLivePhotoBlock: { (photoView, imageView) in
          asset?.loadImage(completion: { (image) in
            imageView?.image = image
          })
          photoView?.livePhoto = livePhoto
          return size
        }))
        return
      }
    }

    if type == kUTTypeImage as String {
      if let url = url, url.absoluteString.uppercased().contains("GIF"), let asset = asset {
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
      if let url = url {
        datum[0].append(MediaResource(setImageBlock: { (imageView) in
          PHAsset.fetchAssets(withALAssetURLs: [url], options: nil).firstObject?.loadImage(completion: { (image) in
            imageView?.image = image
          })
        }))
        return
      }
      if let asset = asset {
        datum[0].append(MediaResource(setImageBlock: { (imageView) in
          asset.loadImage(completion: { (image) in
            imageView?.image = image
          })
        }))
        return
      }
      if let edited = edited {
        datum[0].append(MediaResource(setImageBlock: { (imageView) in
          imageView?.image = edited
        }))
        return
      }
      if let original = original {
        datum[0].append(MediaResource(setImageBlock: { (imageView) in
          imageView?.image = original
        }))
        return
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
