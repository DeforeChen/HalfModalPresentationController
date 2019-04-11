//
//  HalfModalTransitioningDelegate.swift
//  HalfModalPresentationController
//
//  Created by Martin Normark on 17/01/16.
//  Copyright © 2016 martinnormark. All rights reserved.
//

import UIKit

protocol Draggable {
    func draggableArea() -> UIView
}

class HalfModalTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    static let shared = HalfModalTransitioningDelegate()
    
    func takeoverDelegate(presentingViewController: UIViewController & Draggable) {
        presentingViewController.modalPresentationStyle = .custom
        presentingViewController.transitioningDelegate  = self
    }
    
    // MARK: - UIViewControllerTransitioningDelegate
    // 由谁负责具体的动画及实现细节
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return HalfModalTransitionAnimator(type: .Dismiss)
    }
    
    // 转场的主管,管理 页面的呈现与被呈现
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        
        guard presented is Draggable else { return nil }
        return HalfModalPresentationController(presentedViewController: presented as! UIViewController & Draggable, presenting: presenting)
    }
}
