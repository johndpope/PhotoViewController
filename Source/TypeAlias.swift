//
//  TypeAlias.swift
//  PhotoViewController
//
//  Created by Felicity on 8/26/18.
//  Copyright © 2018 Prime. All rights reserved.
//

import UIKit

#if swift(>=4.2)

typealias GestureRecognizerState = UIGestureRecognizer.State
typealias LayoutConstraintAttribute = NSLayoutConstraint.Attribute
public typealias PageViewControllerNavigationOrientation = UIPageViewController.NavigationOrientation
public typealias PageViewControllerTransitionStyle = UIPageViewController.TransitionStyle
public typealias ViewContentMode = UIView.ContentMode
public typealias ViewAnimationOptions = UIView.AnimationOptions
public typealias ViewAnimationCurve = UIView.AnimationCurve

#else

typealias GestureRecognizerState = UIGestureRecognizerState
typealias LayoutConstraintAttribute = NSLayoutAttribute
public typealias PageViewControllerTransitionStyle = UIPageViewControllerTransitionStyle
public typealias PageViewControllerNavigationOrientation = UIPageViewControllerNavigationOrientation
public typealias ViewContentMode = UIViewContentMode
public typealias ViewAnimationOptions = UIViewAnimationOptions
public typealias ViewAnimationCurve = UIViewAnimationCurve

#endif
