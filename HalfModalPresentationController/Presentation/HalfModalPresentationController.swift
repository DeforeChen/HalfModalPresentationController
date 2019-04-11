//
//  HalfModalPresentationController.swift
//  HalfModalPresentationController
//
//  Created by Martin Normark on 17/01/16.
//  Copyright © 2016 martinnormark. All rights reserved.
//

import UIKit

enum ModalScaleState {
    case maxScale
    case semiScale
    
    func obtainFrame(presentContainerFrame: CGRect) -> CGRect {
        switch self {
        case .maxScale:
            // TODO 最大范围
//            CGRect(origin: CGPoint(x: 0, y: containerFrame.height / 3),
//                   size: CGSize(width: containerFrame.width, height: containerFrame.height * 2 / 3))
            return presentContainerFrame
        case .semiScale:
            let semiFrame = CGRect(origin: CGPoint(x: 0, y: presentContainerFrame.height / 2),
                                   size: CGSize(width: presentContainerFrame.width, height: presentContainerFrame.height / 2))
            return semiFrame
        }
    }
}

enum DragDirection {
    case down, up
}

extension DragDirection {
    init(_ dragOffset: CGFloat) {
        if dragOffset > 0 {
            self = .down
        } else {
            self = .up
        }
    }
}

class HalfModalPresentationController : UIPresentationController {
    var isMaximized: Bool = false
    
    var _dimmingView: UIButton?
    var panGestureRecognizer: UIPanGestureRecognizer
    var direction: DragDirection = .up
    var state: ModalScaleState = .semiScale
    
    var dimmingView: UIButton {
        if let dimmedView = _dimmingView {
            return dimmedView
        }
        
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: containerView!.bounds.width, height: containerView!.bounds.height))
        
        // Blur Effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        view.addSubview(blurEffectView)
        
        // Vibrancy Effect
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyEffectView.frame = view.bounds
        
        // Add the vibrancy view to the blur view
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        view.addTarget(self, action: #selector(tapDimmingToDismiss), for: .touchUpInside)
        _dimmingView = view
        
        return view
    }
    
    init(presentedViewController: UIViewController & Draggable, presenting presentingViewController: UIViewController?) {
        self.panGestureRecognizer = UIPanGestureRecognizer()
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        panGestureRecognizer.addTarget(self, action: #selector(onPan(pan:)))
        presentedViewController.draggableArea().addGestureRecognizer(panGestureRecognizer)
    }
    
    @objc private func tapDimmingToDismiss() {
        presentedViewController.dismiss(animated: true, completion: nil) // 继续下滑,那么页面 dismiss
    }
    
    @objc private func onPan(pan: UIPanGestureRecognizer) -> Void {
        var endPoint = pan.translation(in: pan.view?.superview)
        endPoint = CGPoint(x: endPoint.x, y: endPoint.y + UIApplication.shared.statusBarFrame.height) // 适配 iPhone X 系列
        
        switch pan.state {
        case .began:
            print("开始拖曳")
            presentedView!.frame.size.height = containerView!.frame.height
        case .changed:
            print("拖曳中 ...")
            let velocity = pan.velocity(in: pan.view?.superview)
            print(velocity.y)
            switch state {
            case .semiScale:
                presentedView!.frame.origin.y = endPoint.y + containerView!.frame.height / 2
            case .maxScale:
                presentedView!.frame.origin.y = endPoint.y
            }
            direction = DragDirection.init(velocity.y)
        case .ended:
            print("拖曳完毕")
            switch direction {
            case .up:
                changeScaleOnEndDragging(to: .maxScale)
            case .down:
                if state == .maxScale {
                    changeScaleOnEndDragging(to: .semiScale) // 先滑到部分展示
                } else {
                     // 继续下滑,那么页面 dismiss, 这里加了一个优化, 因为从一半位置执行 dismiss, 会有一个短暂的卡顿,所以自己使用动画来实现
                    UIView.animate(withDuration: 0.1, animations: {
                        self.presentedView?.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width: UIScreen.main.bounds.width, height: 0)
                    }) { (_) in
                        self.presentedViewController.dismiss(animated: false, completion: nil)
                    }
                }
            }
            
            print("finished transition")
        default:
            break
        }
    }
    
    func changeScaleOnEndDragging(to state: ModalScaleState) {
        guard let presentedView = presentedView, let containerView = self.containerView else { return }
        
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.1, options: .curveLinear, animations: { () -> Void in
            presentedView.frame = containerView.frame
            let containerFrame = containerView.frame
            let frame = state.obtainFrame(presentContainerFrame: containerFrame)
            presentedView.frame = frame
            
            if let navController = self.presentedViewController as? UINavigationController {
                self.isMaximized = true
                
                navController.setNeedsStatusBarAppearanceUpdate()
                
                // Force the navigation bar to update its size
                navController.isNavigationBarHidden = true
                navController.isNavigationBarHidden = false
            }
        }, completion: { (isFinished) in
            self.state = state
        })
    }
    
    // MARK: - Override Functions
    // 动画结束时 presentView 的位置和大小
    override var frameOfPresentedViewInContainerView: CGRect {
        return ModalScaleState.semiScale.obtainFrame(presentContainerFrame: containerView!.frame)
    }
    
    override func presentationTransitionWillBegin() {
        let dimmedView = dimmingView
        
        if let containerView = self.containerView, let coordinator = presentingViewController.transitionCoordinator {
            
            dimmedView.alpha = 0
            containerView.addSubview(dimmedView)
            dimmedView.addSubview(presentedViewController.view)
            
            coordinator.animate(alongsideTransition: { (context) -> Void in
                dimmedView.alpha = 1
                // 对底层页面控制器作缩放操作
                self.presentingViewController.view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: nil)
        }
    }
    
    override func dismissalTransitionWillBegin() {
        if let coordinator = presentingViewController.transitionCoordinator {
            
            coordinator.animate(alongsideTransition: { (context) -> Void in
                self.dimmingView.alpha = 0
                self.presentingViewController.view.transform = CGAffineTransform.identity // 恢复底层视图大小
            }, completion: { (completed) -> Void in
                print("done dismiss animation")
            })
            
        }
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        print("dismissal did end: \(completed)")
        
        if completed {
            dimmingView.removeFromSuperview()
            _dimmingView = nil
            
            isMaximized = false
        }
    }
}

protocol HalfModalPresentable { }

extension HalfModalPresentable where Self: UIViewController {
    func maximizeToFullScreen() -> Void {
        if let presetation = navigationController?.presentationController as? HalfModalPresentationController {
            presetation.changeScaleOnEndDragging(to: .maxScale)
        }
    }
}

extension HalfModalPresentable where Self: UINavigationController {
    func isHalfModalMaximized() -> Bool {
        if let presentationController = presentationController as? HalfModalPresentationController {
            return presentationController.isMaximized
        }
        
        return false
    }
}
