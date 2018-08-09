//
//  Setting.swift
//  Example
//
//  Created by Felicity on 8/7/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

class SettingViewController: UITableViewController {

  let list: [ExampleConfigWrapper] = ExampleConfigManager.shared.list

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 40
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return list.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    cell.selectionStyle = .none
    let config = list[indexPath.row]
    let label = cell.contentView.firstSubview(ofType: UILabel.self)!
    label.text = config.name
    let seg = cell.contentView.firstSubview(ofType: UISegmentedControl.self)!
    seg.tag = 1000 + indexPath.row
    seg.removeAllSegments()
    seg.addTarget(self, action: #selector(changeIndex(_:)), for: UIControl.Event.valueChanged)
    config.availableStrings.enumerated().forEach { (offset, element) in
      seg.insertSegment(withTitle: element, at: offset, animated: false)
    }
    seg.selectedSegmentIndex = config.selectedIndex
    return cell
  }

  @objc func changeIndex(_ segment: UISegmentedControl) -> Void {
    let row = segment.tag - 1000
    let config = list[row]
    config.selectedIndex = segment.selectedSegmentIndex
  }

}
