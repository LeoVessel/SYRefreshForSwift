//
//  SYRefreshView.swift
//  SYRefreshExample
//
//  Created by shusy on 2017/6/8.
//  Copyright © 2017年 SYRefresh. All rights reserved.
//  代码地址: https://github.com/shushaoyong/SYRefreshForSwift

import UIKit

/**刷新控件的状态 */
enum SYRefreshViewState {
    case stateIdle       /** 普通闲置状态 */
    case pulling        /** 松开就可以进行进行刷新的状态 */
    case refreshing   /** 正在刷新的状态 */
    case noMoreData   /** 没有更多数据的状态 */
}

/// 刷新控件的方向
/// - top:    上边
/// - left:   左边
/// - bottom: 下边
/// - right:  右边
enum RefreshViewOrientation {
    case top
    case left
    case bottom
    case right
}

class RefreshView: UIView {
    /**是否添加到尾部*/
    public var isFooter:Bool = false
    /**设置尾部自动刷新 比例，当用户拖拽到百分之几的时候开始自动加载更多数据 取值：0.0-1.0 默认值1.0代表100%，也就是刷新控件完全显示的时候开始刷新*/
    public var footerAutoRefreshProgress:CGFloat = 1.0
    /**保存当前刷新控件方向*/
    public var orientation:RefreshViewOrientation
    /**保存当前刷新控件的状态*/
    var state : SYRefreshViewState = .stateIdle
    /**UIScrollView控件*/
    private weak var scrollview:UIScrollView?{
        return superview as? UIScrollView
    }
    /**是否正在刷新*/
    var isRefreshing:Bool = false
    {
        didSet{
            if checkContentSizeValid() { return }
            updateRefreshState(isRefreshing: isRefreshing)
        }
    }
    /**当前的拖拽比例*/
    private  var pullProgress:CGFloat = 0 {
        didSet{
            if isRefreshing { return }
            if checkContentSizeValid() { return }
            updatePullProgress(progress: pullProgress)
        }
    }
    /**ScrollView的pan手势*/
    private var panGestureRecognizer: UIPanGestureRecognizer?
    
    /**开始刷新后的回调*/
    private let completionCallBack:()->Void

    /// 初始化方法
    /// - Parameters:
    ///   - orientaton: 控件的方向
    ///   - height: 控件的高度
    ///   - completion: 进入刷新后的回调
    public init(orientaton: RefreshViewOrientation,height:CGFloat,completion:@escaping ()->Void) {
        var isFooter = false
        if orientaton == .bottom || orientaton == .right { isFooter = true }
        self.completionCallBack = completion
        self.isFooter = isFooter
        self.orientation = orientaton
        super.init(frame: .zero)
        updatePullProgress(progress: pullProgress)
        self.isHidden = true
        self.bounds.size.height = height
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
   
    /// 更新刷新状态 此方法交给子类重写
    /// - Parameter isRefresh: 是否正在刷新
    open func updateRefreshState(isRefreshing:Bool){
        fatalError("updateRefreshState(isRefreshing:) has not been implemented")
    }

    /// 拖拽比例 此方法交给子类重写
    /// - Parameter progress: 拖拽比例
    open func updatePullProgress(progress:CGFloat){
        fatalError("updatePullProgress(progress:) has not been implemented")
    }
    
    /// 将要添加到父控件的时候调用此方法 系统调用
    /// - Parameter newSuperview: 将要添加到的父控件
    override func willMove(toSuperview newSuperview: UIView?) {
        removeObserver()
    }
    
    override func didMoveToSuperview() {
        panGestureRecognizer = scrollview?.panGestureRecognizer
        addObserver()
        guard let scrollview = scrollview else { return }
        if isLeftOrRightOrientation() {
            self.frame = CGRect(x: 0, y: 0, width: bounds.height, height: scrollview.bounds.height)
            if isFooter == false {
                self.frame.origin.x = -bounds.width
            }
        }else{
            self.frame = CGRect(x: 0, y: 0, width: scrollview.bounds.width, height: bounds.height)
            if isFooter == false {
                self.frame.origin.y = -bounds.height
            }
        }
    }

    /// 监听scrollview的状态
    func addObserver(){
        scrollview?.addObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset), options: .new, context: nil)
        panGestureRecognizer?.addObserver(self, forKeyPath: #keyPath(UIPanGestureRecognizer.state), options: .new, context: nil)
        if isFooter {
            scrollview?.addObserver(self, forKeyPath: #keyPath(UIScrollView.contentSize), options: .new, context: nil)
        }
    }
    
    /// 移除监听scrollview的状态
    func removeObserver(){
        scrollview?.removeObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset))
        panGestureRecognizer?.removeObserver(self, forKeyPath: #keyPath(UIPanGestureRecognizer.state))
        if isFooter {
            superview?.removeObserver(self, forKeyPath: #keyPath(UIScrollView.contentSize))
        }
    }
    
    /// 监听方法 由系统调用
    /// - Parameters:
    ///   - keyPath: 监听的值
    ///   - object: 监听的对象
    ///   - change: 被监听的值
    ///   - context: 上下文
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let scrollview = scrollview else { return }
        if keyPath == #keyPath(UIScrollView.contentOffset)  {
            contentOffsetChange()
        }else if keyPath == #keyPath(UIScrollView.contentSize){
            contentSizeChange()
        }else if keyPath == #keyPath(UIPanGestureRecognizer.state){
            if case .ended =  scrollview.panGestureRecognizer.state {
                scrollviewEndDraging()
            }
        }
    }
    
    /// 开始刷新
    func beginRefreshing(){
        if isRefreshing {return}
        if checkContentSizeValid() { return }
        guard let scrollview = scrollview else { return } //作用：在下面使用scrollview的时候不用解包
        isRefreshing = true
        pullProgress = 1
        self.setState(state: .refreshing)
        if isLeftOrRightOrientation() {
            UIView.animate(withDuration: RefreshConfig.animationDuration, animations: {
                if self.isFooter {
                    scrollview.contentInset.right += self.bounds.width
                }else{
                    scrollview.contentOffset.y = self.bounds.width + scrollview.contentInset.left
                    scrollview.contentInset.left += self.bounds.width
                }
            }) { (true) in
                self.completionCallBack()
            }
        }else{
            UIView.animate(withDuration: RefreshConfig.animationDuration, animations: {
                if self.isFooter {
                    scrollview.contentInset.bottom += self.bounds.height
                }else{
                    scrollview.contentOffset.y = -self.bounds.height - scrollview.contentInset.top
                    scrollview.contentInset.top += self.bounds.height
                }
            }) { (true) in
                self.completionCallBack()
            }
        }
    }
    
    /// 结束刷新
    func endRefreshing(){
        guard let scrollview = scrollview else { return } //作用：在下面使用scrollview的时候不用解包
        if isLeftOrRightOrientation() {
            UIView.animate(withDuration: RefreshConfig.animationDuration, animations: {
                if self.isFooter {
                    scrollview.contentInset.right -= self.bounds.width
                }else{
                    scrollview.contentInset.left -= self.bounds.width
                }
            }) { (true) in
                self.isRefreshing = false
                self.pullProgress = 0
                self.setState(state: .stateIdle)
            }
        }else{
            UIView.animate(withDuration: RefreshConfig.animationDuration, animations: {
                if self.isFooter {
                    scrollview.contentInset.bottom -= self.bounds.height
                }else{
                    scrollview.contentInset.top -= self.bounds.height
                }
            }) { (true) in
                self.isRefreshing = false
                self.pullProgress = 0
                self.isHidden = true
                self.setState(state: .stateIdle)
            }
        }
    }
    
    /// 设置刷新控件的状态
    /// - Parameter state: 状态
    open func setState(state:SYRefreshViewState){}
    
    /// 返回是否是左右刷新方向
    open func isLeftOrRightOrientation()->Bool{
        return orientation == .left || orientation == .right
    }
    
//===========================私有方法==================================
    /// contentOffset 改变之后调用此方法
    private func contentOffsetChange(){
        if isRefreshing { return}
        guard let scrollview = scrollview else { return }
        if scrollview.isDragging {
            if isLeftOrRightOrientation() { //水平刷新
                if isFooter {
                    pullProgress = min(1,max(0,(scrollview.contentOffset.x+scrollview.bounds.width-scrollview.contentSize.width-scrollview.contentInset.right)/self.bounds.width)) //去除无效的值
                    //设置刷新控件状态
                    let pullingOffsetX = scrollview.contentSize.width - scrollview.bounds.width+bounds.width;
                    let offsetX = scrollview.contentOffset.x
                    if (self.state == .stateIdle && offsetX>pullingOffsetX) {
                        self.setState(state: .pulling)
                    }else if(self.state == .pulling&&offsetX<pullingOffsetX){
                        self.setState(state: .stateIdle)
                    }
                }else{
                    pullProgress = min(1,max(0,-(scrollview.contentOffset.x + scrollview.contentInset.right)/self.bounds.width))
                    //设置刷新控件状态
                    let pullingOffsetX = -scrollview.contentInset.left - bounds.width
                    let offsetX = scrollview.contentOffset.x
                    if (self.state == .stateIdle && offsetX<pullingOffsetX) { //负数 往下拉
                        self.setState(state: .pulling)
                    }else if(self.state == .pulling&&offsetX>pullingOffsetX){
                        self.setState(state: .stateIdle)
                    }
                }
            }else{
                if isFooter {
                    pullProgress = min(1,max(0,(scrollview.contentOffset.y+scrollview.bounds.height-scrollview.contentSize.height-scrollview.contentInset.bottom)/self.bounds.height)) //去除无效的值
                    //设置刷新控件状态
                    let pullingOffsetY = scrollview.contentSize.height - scrollview.bounds.height+bounds.height;
                    let offsetY = scrollview.contentOffset.y
                    if (self.state == .stateIdle && offsetY>pullingOffsetY) {
                        self.setState(state: .pulling)
                    }else if(self.state == .pulling&&offsetY<pullingOffsetY){
                        self.setState(state: .stateIdle)
                    }
                }else{
                    pullProgress = min(1,max(0,-(scrollview.contentOffset.y + scrollview.contentInset.top)/self.bounds.height))
                    //设置刷新控件状态
                    let pullingOffsetY = -scrollview.contentInset.top - bounds.height
                    let offsetY = scrollview.contentOffset.y
                    if (self.state == .stateIdle && offsetY<pullingOffsetY) { //负数 往下拉
                        self.setState(state: .pulling)
                    }else if(self.state == .pulling&&offsetY>pullingOffsetY){
                        self.setState(state: .stateIdle)
                    }
                }
            }
            if isHidden { self.isHidden = false }
            footerAutoRefresh()
        }
    }
    
    /// 开启尾部自动刷新
   private func footerAutoRefresh(){
        if isFooter == false {  return }
        guard let scrollview = scrollview else { return }
        if checkContentSizeValid() == false {
            if isLeftOrRightOrientation() {//水平方向自动刷新
                //开启自动刷新
                if footerAutoRefreshProgress >= 0.0 && footerAutoRefreshProgress < 1.0{
                    if (scrollview.contentOffset.x>=(scrollview.contentSize.width-scrollview.bounds.width-scrollview.contentInset.right-bounds.height)*footerAutoRefreshProgress) {
                        beginRefreshing()
                        return;
                    }
                }
            }else{ //垂直方向自动刷新
                //开启自动刷新
                if footerAutoRefreshProgress >= 0.0 && footerAutoRefreshProgress < 1.0{
                    if (scrollview.contentOffset.y>=(scrollview.contentSize.height-scrollview.bounds.height-scrollview.contentInset.bottom-bounds.height)*footerAutoRefreshProgress) {
                        beginRefreshing()
                        return;
                    }
                }
            }
        }
    }
    
    /// 校验contentsize是否有效果
    private func checkContentSizeValid()->Bool{
        if isFooter == false { return false }
        guard let scrollview = scrollview else { return false} //作用：在下面使用scrollview的时候不用解包
        if isLeftOrRightOrientation() {
            //当内容不满一个屏幕的时候就隐藏底部的刷新控件
            if (scrollview.contentSize.width < scrollview.bounds.width) {
                scrollview.sy_footer?.isHidden = true
                return true
            }else{
                scrollview.sy_footer?.isHidden = false
                return false
            }
        }else{
            //当内容不满一个屏幕的时候就隐藏底部的刷新控件
            if (scrollview.contentSize.height < scrollview.bounds.height) {
                scrollview.sy_footer?.isHidden = true
                return true
            }else{
                scrollview.sy_footer?.isHidden = false
                return false
            }
        }
    }

    /// contentSize 改变之后调用此方法
    private func contentSizeChange(){
        guard let scrollview = scrollview else { return } //作用：在下面使用scrollview的时候不用解包
        if isLeftOrRightOrientation() {
            if checkContentSizeValid() { return }
            if self.bounds.minX ==  scrollview.contentSize.width{return}
            self.frame.origin.x = scrollview.contentSize.width
        }else{
            if checkContentSizeValid() { return }
            if self.frame.origin.y ==  scrollview.contentSize.height{return}
            self.frame.origin.y = scrollview.contentSize.height
        }
    }
    
    /// 将要结束拖拽的时候调用此方法
    private func scrollviewEndDraging(){
        if isRefreshing || pullProgress < 1 {return}  //如果正在刷新 或者 用户没有拖拽到临界点 就不要刷新
        beginRefreshing()
    }
    
    deinit {
        removeObserver()
    }
}

struct VerticalHintText {
    static let headerNomalText:String = "下拉即可刷新"   /// 头部默认状态提示文字
    static let headerPullingText:String = "松手即可刷新" ///头部拖拽状态提示文字
    static let headerRefreshText:String = "刷新中..."   ///头部刷新状态提示文字
    static let footerNomalText:String = "上拉加载更多"   /// 尾部默认状态提示文字
    static let footerPullingText:String = "松手加载更多" ///尾部拖拽状态提示文字
    static let footerRefreshText:String = "加载中..."   ///尾部刷新状态提示文字
    static let footerNomoreDataText:String = "———— 别再拉了，再拉我也长不高 ————"   ///尾部刷新状态提示文字
}

struct HorizontalHintText {
    static let headerNomalText:String = "右边拉即可刷新"   /// 头部默认状态提示文字
    static let headerPullingText:String = "松手即可刷新" ///头部拖拽状态提示文字
    static let headerRefreshText:String = "刷新中..."   ///头部刷新状态提示文字
    static let footerNomalText:String = "左拉加载更多"   /// 尾部默认状态提示文字
    static let footerPullingText:String = "松手加载更多" ///尾部拖拽状态提示文字
    static let footerRefreshText:String = "加载中..."   ///尾部刷新状态提示文字
    static let footerNomoreDataText:String = "— 别再拉了，再拉我也变不长 —"   ///尾部刷新状态提示文字
}

struct RefreshConfig {
    static let animationDuration:TimeInterval = 0.3   /// 默认动画时间
    static let height:CGFloat = 44                     /// 默认刷新控件高度
    static let color:UIColor = UIColor.black           /// 默认字体颜色
    static let font:UIFont = UIFont.systemFont(ofSize:14)/// 默认字体大小
}
