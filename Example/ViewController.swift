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
            imageView?.af_setImage(withURL: URL(string: urlString)!, placeholderImage: UIImage(named: "placeholder"))
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

  func showController(at indexPath: IndexPath, previewing: Bool) -> UIViewController? {
    selectedIndexP = indexPath
    PhotoViewManager.default.defaultImmersiveMode = defaultState
    PhotoViewManager.default.viewTapAction = viewTapAction
    PhotoViewManager.default.interactiveDismissDirection = panDirection
    PhotoViewManager.default.interactiveDismissScaleFactor = panScale
    if previewing {
      let cell = tableView.cellForRow(at: indexPath)!
      PhotoViewManager.default.hintImage = cell.contentView.firstSubview(ofType: UIImageView.self)?.image
    }
    let customPage = CustomPhotoPageController(modally: modally, startIndex: indexPath, resources: datum, navigationOrientation: scrollDirection)
    customPage.page!.loop = pageLoop
    customPage.transitioningDelegate = transitionProvider
    customPage.modalPresentationStyle = .custom
    customPage.page!.didScrollToPageHandler = { [weak customPage, weak self] idxPath in
      guard let strongself = self else { return }
      customPage?.pageControl?.numberOfPages = strongself.datum[idxPath.section].count
      customPage?.pageControl?.currentPage = idxPath.row
    }
    customPage.page!.resourcesDeleteDidCompleteHandler = { [weak self] idxPath, _ in
      guard let strongself = self else { return }
      strongself.datum.removeItemAt(indexPath: idxPath)
      strongself.tableView.reloadData()
    }
    customPage.view.alpha = 1
    customPage.isForceTouching = previewing
    customPage.hidesBottomBarWhenPushed = true
    return customPage
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
    let customPage = showController(at: indexPath, previewing: false)!
    if modally {
      navigationController?.present(customPage, animated: true, completion: nil)
    } else {
      navigationController?.delegate = transitionProvider
      navigationController?.pushViewController(customPage, animated: true)
    }
  }

  lazy var transitionProvider = PhotoZoomInOutTransitionProvider(delegate: self)

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
    if modally {
      navigationController?.present(viewControllerToCommit, animated: true, completion: nil)
    } else {
      navigationController?.delegate = transitionProvider
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


// MARK: - custom transition
extension ViewController {

  func photoZoomInTransition(incoming viewController: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    guard let selectedIndexP = selectedIndexP else { return nil }
    guard let cell = tableView.cellForRow(at: selectedIndexP) else { return nil }
    guard let imageView = cell.contentView.firstSubview(ofType: UIImageView.self) else { return nil }
    guard let viewController = viewController as? CustomPhotoPageController else { return nil }
    let image = imageView.image

    let t = ZoomInAnimatedTransitioning(duration: showingInterval,
                                       option: animationOption(forShowing: true),
                                       provider: PhotoZoomInProvider(source: SmallPhotoViewProvider(imageView: imageView, image: image),
                                                                     destionation: viewController.page!),
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

  func photoZoomOutTransition(outgoing viewController: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    guard let viewController = viewController as? CustomPhotoPageController else { return nil }
    let selectedIndexP = viewController.page!.userCurrentIndexPath
    guard tableView.numberOfSections > selectedIndexP.section && tableView.numberOfRows(inSection: selectedIndexP.section) > selectedIndexP.row  else {
      return nil
    }
    tableView.scrollToRow(at: selectedIndexP, at: .none, animated: false)
    guard let cell = tableView.cellForRow(at: selectedIndexP) else { return nil }
    guard let imageView = cell.contentView.firstSubview(ofType: UIImageView.self) else { return nil }

    let t = ZoomOutAnimatedTransitioning(duration: dismissInterval,
                                         option: animationOption(forShowing: false),
                                         provider: PhotoZoomOutProvider(source: viewController.page!,
                                                                        destionation: SmallPhotoViewProvider(imageView: imageView, image: nil)),
                                         animationWillBegin: {
                                          imageView.isHidden = true },
                                         animationDidFinish: { _ in
                                          imageView.isHidden = false })
    t.prepareAnimation = { imageView in
      imageView.clipsToBounds = true
      imageView.layer.cornerRadius = 0
    }
    t.userAnimation = { interactive, cancelled, progress, imageView in
      if !interactive {
        imageView.layer.cornerRadius = cancelled ? 0 : cornerRadius
      }
    }
    t.transitionDidFinish = { [weak self] (completed) in
      if completed {
        self?.navigationController?.delegate = nil
      }
    }
    return t
  }

}

extension ViewController: PhotoZoomInOutTransitionProviderDelegate {}

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
