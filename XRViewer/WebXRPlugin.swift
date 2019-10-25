import Foundation
import AVFoundation
import WebKit
import ARKit
import MetalKit

@objc(WebXRPlugin)
class WebXRPlugin : CDVPlugin {
    private var arkLayerView: UIView!
    lazy var stateController: AppStateController = AppStateController(state: AppState.defaultState())
    var arkController: ARKController?
    var webController: WebController?
//    private var locationManager: LocationManager?
    private var animator: Animator?
    private var timerSessionRunningInBackground: Timer?
    private var deferredHitTest: (Int, CGFloat, CGFloat, ResultArrayBlock)? = nil
    private var savedRender: Block? = nil
    
    // Properties for status messages via messageLabel & messagePanel
    var schedulingMessagesBlocked = false
    // Timer for hiding messages
    var messageHideTimer: Timer?
    // Timers for showing scheduled messages
    var focusSquareMessageTimer: Timer?
    var planeEstimationMessageTimer: Timer?
    var contentPlacementMessageTimer: Timer?
    // Timer for tracking state escalation
    var trackingStateFeedbackEscalationTimer: Timer?
    
    // MARK: - View Lifecycle
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func pluginInitialize() {
        super.pluginInitialize()
        
        arkLayerView = UIView(frame: UIScreen.main.bounds)
        self.webView.superview?.insertSubview(arkLayerView, belowSubview: self.webView)

        setupCommonControllers()
        setupSinglePlaneButton()
        
        setupTargetControllers()
    }

    // 9/3/19: Commenting to monitor default failure response and frequency
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        appDelegate().logger.error("didReceiveMemoryWarning")
//        processMemoryWarning()
//    }

//    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        let webXR = stateController.state.webXR
//        // Disable the transition animation if we are on XR
//        if webXR {
//            coordinator.animate(alongsideTransition: nil) { context in
//                UIView.setAnimationsEnabled(true)
//            }
//            UIView.setAnimationsEnabled(false)
//        }
//
//        arkController?.viewWillTransition(to: size)
//        overlayController?.viewWillTransition(to: size)
//        webController?.viewWillTransition(to: size)
//
//        super.viewWillTransition(to: size, with: coordinator)
//    }

//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        updateConstraints()
//    }

    func updateConstraints() {
        guard let webViewTop = webController?.webViewTopAnchorConstraint else { return }
        guard let webViewLeft = webController?.webViewLeftAnchorConstraint else { return }
        guard let webViewRight = webController?.webViewRightAnchorConstraint else { return }
        let webXR = stateController.state.webXR
        // If XR is active, then the top anchor is 0 (fullscreen), else topSafeAreaInset + Constant.urlBarHeight()
        let topSafeAreaInset = UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0.0
        webViewTop.constant = webXR ? 0.0 : topSafeAreaInset + Constant.urlBarHeight()

        webViewLeft.constant = 0.0
        webViewRight.constant = 0.0
        if !stateController.state.webXR {
            let currentOrientation: UIInterfaceOrientation = Utils.getInterfaceOrientationFromDeviceOrientation()
            if currentOrientation == .landscapeLeft {
                // The notch is to the right
                let rightSafeAreaInset = UIApplication.shared.keyWindow?.safeAreaInsets.right ?? 0.0
                webViewRight.constant = webXR ? 0.0 : -rightSafeAreaInset
            } else if currentOrientation == .landscapeRight {
                // The notch is to the left
                let leftSafeAreaInset = CGFloat(UIApplication.shared.keyWindow?.safeAreaInsets.left ?? 0.0)
                webViewLeft.constant = leftSafeAreaInset
            }
        }

        // webLayerView.setNeedsLayout()
        // webLayerView.layoutIfNeeded()
    }

    // MARK: - Setup
    
    func setupCommonControllers() {
        setupStateController()
        setupAnimator()
        setupNotifications()
    }

    func setupStateController() {
        weak var blockSelf: WebXRPlugin? = self

        stateController.onDebug = { showDebug in
            blockSelf?.webController?.showDebug(showDebug)
        }

        stateController.onModeUpdate = { mode in
            blockSelf?.arkController?.setShowMode(mode)
        }

        stateController.onOptionsUpdate = { options in
            blockSelf?.arkController?.setShowOptions(options)
        }

        stateController.onXRUpdate = { xr in
            if xr {
                // guard let debugSelected = blockSelf?.webController?.isDebugButtonSelected() else { return }
                // guard let shouldShowSessionStartedPopup = blockSelf?.stateController.state.shouldShowSessionStartedPopup else { return }
                
                // if debugSelected {
                //     blockSelf?.stateController.setShowMode(.debug)
                // } else {
                //     blockSelf?.stateController.setShowMode(.nothing)
                // }

                // if shouldShowSessionStartedPopup {
                //     blockSelf?.stateController.state.shouldShowSessionStartedPopup = false
                //     blockSelf?.messageController?.showMessage(withTitle: AR_SESSION_STARTED_POPUP_TITLE, message: AR_SESSION_STARTED_POPUP_MESSAGE, hideAfter: AR_SESSION_STARTED_POPUP_TIME_IN_SECONDS)
                // }

                // blockSelf?.webController?.lastXRVisitedURL = blockSelf?.webController?.webView?.url?.absoluteString ?? ""
            } else {
                blockSelf?.stateController.setShowMode(.nothing)
                if blockSelf?.arkController?.arSessionState == .arkSessionRunning {
                    blockSelf?.timerSessionRunningInBackground?.invalidate()
                    let timerSeconds: Int = UserDefaults.standard.integer(forKey: Constant.secondsInBackgroundKey())
                    print(String(format: "\n\n*********\n\nMoving away from an XR site, keep ARKit running, and launch the timer for %ld seconds\n\n*********", timerSeconds))
                    blockSelf?.timerSessionRunningInBackground = Timer.scheduledTimer(withTimeInterval: TimeInterval(timerSeconds), repeats: false, block: { timer in
                        print("\n\n*********\n\nTimer expired, pausing session\n\n*********")
                        UserDefaults.standard.set(Date(), forKey: Constant.backgroundOrPausedDateKey())
                        blockSelf?.arkController?.pauseSession()
                        blockSelf?.timerSessionRunningInBackground?.invalidate()
                        blockSelf?.timerSessionRunningInBackground = nil
                    })
                }
            }
//            blockSelf?.updateConstraints()
            blockSelf?.arkController?.controller.initializingRender = true
            blockSelf?.savedRender = nil
            blockSelf?.webController?.setup(forWebXR: xr)
        }

        stateController.onReachable = { url in
            blockSelf?.loadURL(url)
        }

        stateController.onEnterForeground = { url in
            blockSelf?.stateController.state.shouldRemoveAnchorsOnNextARSession = false

            let requestedURL = UserDefaults.standard.string(forKey: REQUESTED_URL_KEY)
            if requestedURL != nil {
                print("\n\n*********\n\nMoving to foreground because the user wants to open a URL externally, loading the page\n\n*********")
                UserDefaults.standard.set(nil, forKey: REQUESTED_URL_KEY)
                blockSelf?.loadURL(requestedURL)
            } else {
                guard let arSessionState = blockSelf?.arkController?.arSessionState else { return }
                switch arSessionState {
                    case .arkSessionUnknown:
                        print("\n\n*********\n\nMoving to foreground while ARKit is not initialized, do nothing\n\n*********")
                    case .arkSessionPaused:
                        guard let hasWorldMap = blockSelf?.arkController?.hasBackgroundWorldMap() else { return }
                        if !hasWorldMap {
                            // if no background map, then need to remove anchors on next session
                            print("\n\n*********\n\nMoving to foreground while the session is paused, remember to remove anchors on next AR request\n\n*********")
                            blockSelf?.stateController.state.shouldRemoveAnchorsOnNextARSession = true
                        }
                    case .arkSessionRunning:
                        guard let hasWorldMap = blockSelf?.arkController?.hasBackgroundWorldMap() else { return }
                        if hasWorldMap {
                            print("\n\n*********\n\nMoving to foreground while the session is running and it was in BG\n\n*********")

                            print("\n\n*********\n\nARKit will attempt to relocalize the worldmap automatically\n\n*********")
                        } else {
                            let interruptionDate = UserDefaults.standard.object(forKey: Constant.backgroundOrPausedDateKey()) as? Date
                            let now = Date()
                            if let aDate = interruptionDate {
                                if now.timeIntervalSince(aDate) >= Constant.pauseTimeInSecondsToRemoveAnchors() {
                                    print("\n\n*********\n\nMoving to foreground while the session is running and it was in BG for a long time, remove the anchors\n\n*********")
                                    blockSelf?.arkController?.removeAllAnchors()
                                } else {
                                    print("\n\n*********\n\nMoving to foreground while the session is running and it was in BG for a short time, do nothing\n\n*********")
                                }
                            }
                        }
                }
            }

            UserDefaults.standard.set(nil, forKey: Constant.backgroundOrPausedDateKey())
        }

        stateController.onMemoryWarning = { url in
            blockSelf?.arkController?.controller.previewingSinglePlane = false

            blockSelf?.webController?.didReceiveError(error: NSError(domain: MEMORY_ERROR_DOMAIN, code: MEMORY_ERROR_CODE, userInfo: [NSLocalizedDescriptionKey: MEMORY_ERROR_MESSAGE]))
        }

        stateController.onRequestUpdate = { dict in
            defer {
                if dict?[WEB_AR_CV_INFORMATION_OPTION] as? Bool ?? false {
                    blockSelf?.stateController.state.computerVisionFrameRequested = true
                    blockSelf?.arkController?.computerVisionFrameRequested = true
                    blockSelf?.stateController.state.sendComputerVisionData = true
                }
            }
            
            if blockSelf?.timerSessionRunningInBackground != nil {
                print("\n\n*********\n\nInvalidate timer\n\n*********")
                blockSelf?.timerSessionRunningInBackground?.invalidate()
            }
            if let metal = blockSelf?.arkController?.usingMetal,
                metal != UserDefaults.standard.bool(forKey: Constant.useMetalForARKey())
            {
                blockSelf?.savedRender = nil
                blockSelf?.arkController = nil
            }

            if blockSelf?.arkController == nil {
                print("\n\n*********\n\nARKit is nil, instantiate and start a session\n\n*********")
                blockSelf?.startNewARKitSession(withRequest: dict)
            } else {
                guard let arSessionState = blockSelf?.arkController?.arSessionState else { return }
                guard let state = blockSelf?.stateController.state else { return }
                
                if blockSelf?.arkController?.trackingStateRelocalizing() ?? false {
                    blockSelf?.arkController?.runSessionResettingTrackingAndRemovingAnchors(with: state)
                    return
                }
                
                switch arSessionState {
                    case .arkSessionUnknown:
                        print("\n\n*********\n\nARKit is in unknown state, instantiate and start a session\n\n*********")
                        blockSelf?.arkController?.runSessionResettingTrackingAndRemovingAnchors(with: state)
                    case .arkSessionRunning:
                        if let lastTrackingResetDate = UserDefaults.standard.object(forKey: Constant.lastResetSessionTrackingDateKey()) as? Date,
                            Date().timeIntervalSince(lastTrackingResetDate) >= Constant.thresholdTimeInSecondsSinceLastTrackingReset() {
                            print("\n\n*********\n\nSession is running but it's been a while since last resetting tracking, resetting tracking and removing anchors now to prevent coordinate system drift\n\n*********")
                            blockSelf?.arkController?.runSessionResettingTrackingAndRemovingAnchors(with: state)
                        } else if blockSelf?.urlIsNotTheLastXRVisitedURL() ?? false {
                            print("\n\n*********\n\nThis site is not the last XR site visited, and the timer hasn't expired yet. Remove distant anchors and continue with the session\n\n*********")
                            blockSelf?.arkController?.removeDistantAnchors()
                            blockSelf?.arkController?.runSession(with: state)
                        } else {
                            print("\n\n*********\n\nThis site is the last XR site visited, and the timer hasn't expired yet. Continue with the session\n\n*********")
                        }
                    case .arkSessionPaused:
                        print("\n\n*********\n\nRequest of a new AR session when it's paused\n\n*********")
                        guard let shouldRemoveAnchors = blockSelf?.stateController.state.shouldRemoveAnchorsOnNextARSession else { return }
                        if let lastTrackingResetDate = UserDefaults.standard.object(forKey: Constant.lastResetSessionTrackingDateKey()) as? Date,
                            Date().timeIntervalSince(lastTrackingResetDate) >= Constant.thresholdTimeInSecondsSinceLastTrackingReset() {
                            print("\n\n*********\n\nSession is paused and it's been a while since last resetting tracking, resetting tracking and removing anchors on this paused session to prevent coordinate system drift\n\n*********")
                            blockSelf?.arkController?.runSessionResettingTrackingAndRemovingAnchors(with: state)
                        } else if shouldRemoveAnchors {
                            print("\n\n*********\n\nRun session removing anchors\n\n*********")
                            blockSelf?.stateController.state.shouldRemoveAnchorsOnNextARSession = false
                            blockSelf?.arkController?.runSessionRemovingAnchors(with: state)
                        } else {
                            print("\n\n*********\n\nResume session\n\n*********")
                            blockSelf?.arkController?.resumeSession(with: state)
                        }
                }
            }
        }
    }

    func urlIsNotTheLastXRVisitedURL() -> Bool {
        return !(webController?.webView?.url?.absoluteString == webController?.lastXRVisitedURL)
    }

    func startNewARKitSession(withRequest request: [AnyHashable : Any]?) {
        setupLocationController()
//        locationManager?.setup(forRequest: request)
        setupARKController()
    }

    func setupAnimator() {
        self.animator = Animator()
    }

    func setupNotifications() {
        weak var blockSelf: WebXRPlugin? = self
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidEnterBackground, object: nil, queue: OperationQueue.main, using: { note in
            blockSelf?.arkController?.controller.previewingSinglePlane = false
            var arSessionState: ARKitSessionState
            if blockSelf?.arkController?.arSessionState != nil {
                arSessionState = (blockSelf?.arkController?.arSessionState)!
            } else {
                arSessionState = .arkSessionUnknown
            }
            switch arSessionState {
                case .arkSessionUnknown:
                    print("\n\n*********\n\nMoving to background while ARKit is not initialized, nothing to do\n\n*********")
                case .arkSessionPaused:
                    print("\n\n*********\n\nMoving to background while the session is paused, nothing to do\n\n*********")
                    // need to try and save WorldMap here.  May fail?
                    blockSelf?.arkController?.saveWorldMapInBackground()
                case .arkSessionRunning:
                    print("\n\n*********\n\nMoving to background while the session is running, store the timestamp\n\n*********")
                    UserDefaults.standard.set(Date(), forKey: Constant.backgroundOrPausedDateKey())
                    // need to save WorldMap here
                    blockSelf?.arkController?.saveWorldMapInBackground()
            }

            blockSelf?.webController?.didBackgroundAction(true)

            blockSelf?.stateController.saveMoveToBackground(onURL: blockSelf?.webController?.lastURL)
        })

        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: OperationQueue.main, using: { note in
            blockSelf?.stateController.applyOnEnterForegroundAction()
        })

        NotificationCenter.default.addObserver(self, selector: #selector(WebXRPlugin.deviceOrientationDidChange(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }

    @objc func deviceOrientationDidChange(_ notification: Notification?) {
        arkController?.shouldUpdateWindowSize = true
        updateConstraints()
    }

    func setupTargetControllers() {
        setupLocationController()
        setupWebController()
    }

    func setupLocationController() {
//        self.locationManager = LocationManager()
//        locationManager?.setup(forRequest: stateController.state.aRRequest)
    }

    func setupARKController() {
        CLEAN_VIEW(v: arkLayerView)

        weak var blockSelf: WebXRPlugin? = self

        let frameworkString = self.commandDelegate.settings["graphicsframework"] as? String
        arkController = ARKController(type: frameworkString == "metal" ? .arkMetal : .arkSceneKit, rootView: arkLayerView)

        arkController?.didUpdate = {
            guard let shouldSendNativeTime = blockSelf?.stateController.shouldSendNativeTime() else { return }
            guard let shouldSendARKData = blockSelf?.stateController.shouldSendARKData() else { return }
            guard let shouldSendCVData = blockSelf?.stateController.shouldSendCVData() else { return }
            
            if shouldSendNativeTime {
                blockSelf?.sendNativeTime()
                var numberOfTimesSendNativeTimeWasCalled = blockSelf?.stateController.state.numberOfTimesSendNativeTimeWasCalled
                numberOfTimesSendNativeTimeWasCalled = (numberOfTimesSendNativeTimeWasCalled ?? 0) + 1
                blockSelf?.stateController.state.numberOfTimesSendNativeTimeWasCalled = numberOfTimesSendNativeTimeWasCalled ?? 1
            }

            if shouldSendARKData {
                blockSelf?.sendARKData()
            }

            if shouldSendCVData {
                if blockSelf?.sendComputerVisionData() ?? false {
                    blockSelf?.stateController.state.computerVisionFrameRequested = false
                    blockSelf?.arkController?.computerVisionFrameRequested = false
                }
            }
        }
        arkController?.didChangeTrackingState = { camera in
            
//            if let camera = camera,
//                let webXR = blockSelf?.stateController.state.webXR,
//                webXR
//            {
//                blockSelf?.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
//                switch camera.trackingState {
//                case .notAvailable:
//                    return
//                case .limited:
//                    blockSelf?.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
//                case .normal:
//                    blockSelf?.cancelScheduledMessage(forType: .trackingStateEscalation)
//                }
//            }
        }
        arkController?.sessionWasInterrupted = {
            blockSelf?.webController?.wasARInterruption(true)
        }
        arkController?.sessionInterruptionEnded = {
            blockSelf?.webController?.wasARInterruption(false)
        }
        arkController?.didFailSession = { error in
            guard let error = error as NSError? else { return }
            blockSelf?.arkController?.arSessionState = .arkSessionUnknown
            blockSelf?.webController?.didReceiveError(error: error)

            if error.code == SENSOR_FAILED_ARKIT_ERROR_CODE {
                var currentARRequest = blockSelf?.stateController.state.aRRequest
                if currentARRequest?[WEB_AR_WORLD_ALIGNMENT] as? Bool ?? false {
                    // The session failed because the compass (heading) couldn't be initialized. Fallback the session to ARWorldAlignmentGravity
                    currentARRequest?[WEB_AR_WORLD_ALIGNMENT] = false
                    blockSelf?.stateController.setARRequest(currentARRequest ?? [:]) { () -> () in
                        return
                    }
                }
            }

            var errorMessage = "ARKit Error"
            switch error.code {
                case Int(CAMERA_ACCESS_NOT_AUTHORIZED_ARKIT_ERROR_CODE):
                    // If there is a camera access error, do nothing
                    return
                case Int(UNSUPPORTED_CONFIGURATION_ARKIT_ERROR_CODE):
                    errorMessage = UNSUPPORTED_CONFIGURATION_ARKIT_ERROR_MESSAGE
                case Int(SENSOR_UNAVAILABLE_ARKIT_ERROR_CODE):
                    errorMessage = SENSOR_UNAVAILABLE_ARKIT_ERROR_MESSAGE
                case Int(SENSOR_FAILED_ARKIT_ERROR_CODE):
                    errorMessage = SENSOR_FAILED_ARKIT_ERROR_MESSAGE
                case Int(WORLD_TRACKING_FAILED_ARKIT_ERROR_CODE):
                    errorMessage = WORLD_TRACKING_FAILED_ARKIT_ERROR_MESSAGE
                default:
                    break
            }

        }

        arkController?.didUpdateWindowSize = {
            blockSelf?.webController?.updateWindowSize()
        }

        animator?.animate(arkLayerView, toFade: false)

        arkController?.startSession(with: stateController.state)
        
        if arkController?.usingMetal ?? false {
            arkController?.controller.renderer.rendererShouldUpdateFrame = { block in
                if let frame = blockSelf?.arkController?.session.currentFrame {
                    blockSelf?.arkController?.controller.readyToRenderFrame = false
                    blockSelf?.savedRender = block
                    blockSelf?.arkController?.updateARKData(with: frame)
                    blockSelf?.arkController?.didUpdate?()
                } else {
                    print("Unable to updateARKData since ARFrame isn't ready")
                    block()
                }
            }
        }
    }

    func setupWebController() {
        // CLEAN_VIEW(v: webLayerView)

        weak var blockSelf: WebXRPlugin? = self

        self.webController = WebController(withWebView: self.webView as! WKWebView)
        if !ARKController.supportsARFaceTrackingConfiguration() {
//            webController?.hideCameraFlipButton()
        }
        webController?.animator = animator
        webController?.onStartLoad = {
            self.cleanARKController()
            if blockSelf?.arkController != nil {
                blockSelf?.arkController?.controller.previewingSinglePlane = false
                let lastURL = blockSelf?.webController?.lastURL
                let currentURL = blockSelf?.webController?.webView?.url?.absoluteString

                if lastURL == currentURL {
                    // Page reload
                    blockSelf?.arkController?.removeAllAnchorsExceptPlanes()
                } else {
                    blockSelf?.arkController?.detectionImageCreationPromises.removeAllObjects()
                    blockSelf?.arkController?.detectionImageCreationRequests.removeAllObjects()
                }
                
                if let worldTrackingConfiguration = blockSelf?.arkController?.configuration as? ARWorldTrackingConfiguration,
                    worldTrackingConfiguration.detectionImages.count > 0,
                    let state = blockSelf?.stateController.state
                {
                    worldTrackingConfiguration.detectionImages = Set<ARReferenceImage>()
                    blockSelf?.arkController?.runSessionResettingTrackingAndRemovingAnchors(with: state)
                }
            }
            blockSelf?.arkController?.webXRAuthorizationStatus = .notDetermined
            blockSelf?.stateController.setWebXR(false)
        }

        webController?.onFinishLoad = {
            //         [blockSelf hideSplashWithCompletion:^
            //          { }];
        }

        webController?.onInitAR = { uiOptionsDict in
            blockSelf?.stateController.setShowOptions(self.showOptionsFormDict(dict: uiOptionsDict))
            blockSelf?.stateController.applyOnEnterForegroundAction()
            blockSelf?.stateController.applyOnDidReceiveMemoryAction()
            blockSelf?.stateController.state.numberOfTrackedImages = 0
            blockSelf?.arkController?.setNumberOfTrackedImages(0)
            blockSelf?.savedRender = nil
        }

        webController?.onError = { error in
            if let error = error {
                blockSelf?.showWebError(error as NSError)
            }
        }

        webController?.onWatchAR = { request in
            blockSelf?.handleOnWatchAR(withRequest: request, initialLoad: true, grantedPermissionsBlock: nil)
        }
        
        webController?.onRequestSession = { request, grantedPermissions in
            blockSelf?.handleOnWatchAR(withRequest: request, initialLoad: true, grantedPermissionsBlock: grantedPermissions)
        }
        
        webController?.onJSFinishedRendering = {
            blockSelf?.arkController?.controller.initializingRender = false
            blockSelf?.savedRender?()
            blockSelf?.savedRender = nil
            blockSelf?.arkController?.controller.readyToRenderFrame = true
            if let controller = blockSelf?.arkController?.controller as? ARKMetalController {
                controller.draw(in: controller.renderView)
            }
        }

        webController?.onStopAR = {
            blockSelf?.stateController.setWebXR(false)
            blockSelf?.stateController.setShowMode(.nothing)
        }
        
        webController?.onShowPermissions = {
            guard let request = blockSelf?.stateController.state.aRRequest else { return }
            blockSelf?.handleOnWatchAR(withRequest: request, initialLoad: false, grantedPermissionsBlock: nil)
        }

        webController?.onJSUpdateData = {
            return blockSelf?.commonData() ?? [:]
        }

        webController?.loadURL = { url in
            blockSelf?.webController?.loadURL(url)
        }

        webController?.onSetUI = { uiOptionsDict in
            blockSelf?.stateController.setShowOptions(self.showOptionsFormDict(dict: uiOptionsDict))
        }

        webController?.onHitTest = { mask, x, y, result in
            if blockSelf?.arkController?.controller.previewingSinglePlane ?? false {
                print("Wait until after Lite Mode plane selected to perform hit tests")
                blockSelf?.deferredHitTest = (mask, x, y, result)
                return
            }
            if blockSelf?.arkController?.webXRAuthorizationStatus == .lite {
                // Default hit testing is done against plane geometry,
                // (HIT_TEST_TYPE_EXISTING_PLANE_GEOMETRY = 32 = 2^5), but to preserve privacy in
                // .lite Mode only hit test against the plane itself
                // (HIT_TEST_TYPE_EXISTING_PLANE = 8 = 2^3)
                if blockSelf?.arkController?.usingMetal ?? false {
                    var array = [[AnyHashable: Any]]()
                    switch blockSelf?.arkController?.interfaceOrientation {
                    case .landscapeLeft?:
                        array = blockSelf?.arkController?.hitTestNormPoint(CGPoint(x: 1-x, y: 1-y), types: 8) ?? []
                    case .landscapeRight?:
                        array = blockSelf?.arkController?.hitTestNormPoint(CGPoint(x: x, y: y), types: 8) ?? []
                    default:
                        array = blockSelf?.arkController?.hitTestNormPoint(CGPoint(x: y, y: 1-x), types: 8) ?? []
                    }
                    result(array)
                } else {
                    let array = blockSelf?.arkController?.hitTestNormPoint(CGPoint(x: x, y: y), types: 8)
                    result(array)
                }
            } else {
                if blockSelf?.arkController?.usingMetal ?? false {
                    var array = [[AnyHashable: Any]]()
                    switch blockSelf?.arkController?.interfaceOrientation {
                    case .landscapeLeft?:
                        array = blockSelf?.arkController?.hitTestNormPoint(CGPoint(x: 1-x, y: 1-y), types: mask) ?? []
                    case .landscapeRight?:
                        array = blockSelf?.arkController?.hitTestNormPoint(CGPoint(x: x, y: y), types: mask) ?? []
                    default:
                        array = blockSelf?.arkController?.hitTestNormPoint(CGPoint(x: y, y: 1-x), types: mask) ?? []
                    }
                    result(array)
                } else {
                    let array = blockSelf?.arkController?.hitTestNormPoint(CGPoint(x: x, y: y), types: mask)
                    result(array)
                }
            }
        }

        webController?.onAddAnchor = { name, transformArray, result in
            if blockSelf?.arkController?.addAnchor(name, transformHash: transformArray) ?? false {
                if let anArray = transformArray {
                    result([WEB_AR_UUID_OPTION: name ?? 0, WEB_AR_TRANSFORM_OPTION: anArray])
                }
            } else {
                result([:])
            }
        }

        webController?.onRemoveObjects = { objects in
            blockSelf?.arkController?.removeAnchors(objects)
        }

        webController?.onDebugButtonToggled = { selected in
            blockSelf?.stateController.setShowMode(selected ? ShowMode.urlDebug : ShowMode.url)
        }
        
        webController?.onGeometryArraysSet = { geometryArrays in
            blockSelf?.stateController.state.geometryArrays = geometryArrays
        }
        
        webController?.onSettingsButtonTapped = {
            // Before showing the settings popup, we hide the bar and the debug buttons so they are not in the way
            // After dismissing the popup, we show them again.
//            let navigationController = UINavigationController(rootViewController: settingsViewController)
//            weak var weakSettingsViewController = settingsViewController
//            settingsViewController.onDoneButtonTapped = {
//                weakSettingsViewController?.dismiss(animated: true)
//                blockSelf?.webController?.showBar(true)
//                blockSelf?.stateController.setShowMode(.url)
//            }
//
//            blockSelf?.stateController.setShowMode(.nothing)
//            blockSelf?.present(navigationController, animated: true)
        }

        webController?.onComputerVisionDataRequested = {
            blockSelf?.stateController.state.computerVisionFrameRequested = true
            blockSelf?.arkController?.computerVisionFrameRequested = true
        }

        webController?.onResetTrackingButtonTapped = {

//            blockSelf?.messageController?.showMessageAboutResetTracking({ option in
//                guard let state = blockSelf?.stateController.state else { return }
//                switch option {
//                    case .resetTracking:
//                        blockSelf?.arkController?.runSessionResettingTrackingAndRemovingAnchors(with: state)
//                    case .removeExistingAnchors:
//                        blockSelf?.arkController?.runSessionRemovingAnchors(with: state)
//                    case .saveWorldMap:
//                        blockSelf?.arkController?.saveWorldMap()
//                    case .loadSavedWorldMap:
//                        blockSelf?.arkController?.loadSavedMap()
//                }
//            })
        }

        webController?.onStartSendingComputerVisionData = {
            blockSelf?.stateController.state.sendComputerVisionData = true
        }

        webController?.onStopSendingComputerVisionData = {
            blockSelf?.stateController.state.sendComputerVisionData = false
        }
        
        webController?.onSetNumberOfTrackedImages = { number in
            blockSelf?.stateController.state.numberOfTrackedImages = number
            blockSelf?.arkController?.setNumberOfTrackedImages(number)
        }

        webController?.onActivateDetectionImage = { imageName, completion in
            blockSelf?.arkController?.activateDetectionImage(imageName, completion: completion)
        }

        webController?.onGetWorldMap = { completion in
//            let completion = completion as? GetWorldMapCompletionBlock
            blockSelf?.arkController?.getWorldMap(completion)
        }

        webController?.onSetWorldMap = { dictionary, completion in
            blockSelf?.arkController?.setWorldMap(dictionary, completion: completion)
        }

        webController?.onDeactivateDetectionImage = { imageName, completion in
            blockSelf?.arkController?.deactivateDetectionImage(imageName, completion: completion)
        }

        webController?.onDestroyDetectionImage = { imageName, completion in
            blockSelf?.arkController?.destroyDetectionImage(imageName, completion: completion)
        }

        webController?.onCreateDetectionImage = { dictionary, completion in
            blockSelf?.arkController?.createDetectionImage(dictionary, completion: completion)
        }

        webController?.onSwitchCameraButtonTapped = {
//            let numberOfImages = blockSelf?.stateController.state.numberOfTrackedImages ?? 0
//            blockSelf?.arkController?.switchCameraButtonTapped(numberOfImages)
            guard let state = blockSelf?.stateController.state else { return }
            blockSelf?.arkController?.switchCameraButtonTapped(state)
        }

        if stateController.wasMemoryWarning() {
            stateController.applyOnDidReceiveMemoryAction()
        } else {
            let requestedURL = UserDefaults.standard.string(forKey: REQUESTED_URL_KEY)
            if requestedURL != nil && requestedURL != "" {
                UserDefaults.standard.set(nil, forKey: REQUESTED_URL_KEY)
                webController?.loadURL(requestedURL)
            } else {
                let lastURL = UserDefaults.standard.string(forKey: LAST_URL_KEY)
                if lastURL != nil {
                    webController?.loadURL(lastURL)
                } else {
//                    let homeURL = UserDefaults.standard.string(forKey: Constant.homeURLKey())
//                    if homeURL != nil && homeURL != "" {
//                        webController?.loadURL(homeURL)
//                    } else {
//                        webController?.loadURL(WEB_URL)
//                    }
                }
            }
        }
    }
    
    
    private func showOptionsFormDict(dict: [AnyHashable : Any]?) -> ShowOptions {
        if dict == nil {
            return .browser
        }
        
        var options: ShowOptions = .init(rawValue: 0)
        
        if (dict?[WEB_AR_UI_BROWSER_OPTION] as? NSNumber)?.boolValue ?? false {
            options = [options, .browser]
        }
        
        if (dict?[WEB_AR_UI_POINTS_OPTION] as? NSNumber)?.boolValue ?? false {
            options = [options, .arPoints]
        }
        
        if (dict?[WEB_AR_UI_DEBUG_OPTION] as? NSNumber)?.boolValue ?? false {
            options = [options, .debug]
        }
        
        if (dict?[WEB_AR_UI_STATISTICS_OPTION] as? NSNumber)?.boolValue ?? false {
            options = [options, .arStatistics]
        }
        
        if (dict?[WEB_AR_UI_FOCUS_OPTION] as? NSNumber)?.boolValue ?? false {
            options = [options, .arFocus]
        }
        
        if (dict?[WEB_AR_UI_BUILD_OPTION] as? NSNumber)?.boolValue ?? false {
            options = [options, .buildNumber]
        }
        
        if (dict?[WEB_AR_UI_PLANE_OPTION] as? NSNumber)?.boolValue ?? false {
            options = [options, .arPlanes]
        }
        
        if (dict?[WEB_AR_UI_WARNINGS_OPTION] as? NSNumber)?.boolValue ?? false {
            options = [options, .arWarnings]
        }
        
        if (dict?[WEB_AR_UI_ANCHORS_OPTION] as? NSNumber)?.boolValue ?? false {
            options = [options, .arObject]
        }
        
        return options
    }
    
    func setupSinglePlaneButton() {
//        let buttonWidth: CGFloat = 200
//        let buttonHeight: CGFloat = 50
//        chooseSinglePlaneButton = UIButton(type: .roundedRect)
//        chooseSinglePlaneButton.backgroundColor = .white
//        chooseSinglePlaneButton.layer.cornerRadius = 0.5 * buttonHeight
//        chooseSinglePlaneButton.clipsToBounds = true
//        chooseSinglePlaneButton.tintColor = .black
//        chooseSinglePlaneButton.setTitle("Share green plane", for: .normal)
//        chooseSinglePlaneButton.addTarget(self, action: #selector(chooseSinglePlaneAction), for: .touchUpInside)
//        chooseSinglePlaneButton.isHidden = true
//        view.addSubview(chooseSinglePlaneButton)
//        
//        chooseSinglePlaneButton.translatesAutoresizingMaskIntoConstraints = false
//        let horizontalConstraint = chooseSinglePlaneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
//        chooseSinglePlaneButtonVerticalConstraint = chooseSinglePlaneButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: view.frame.height / 4)
//        let widthConstraint = chooseSinglePlaneButton.widthAnchor.constraint(equalToConstant: buttonWidth)
//        let heightConstraint = chooseSinglePlaneButton.heightAnchor.constraint(equalToConstant: buttonHeight)
//        view.addConstraints([horizontalConstraint, chooseSinglePlaneButtonVerticalConstraint, widthConstraint, heightConstraint])
    }

    // MARK: - Cleanups
    
    func cleanupCommonControllers() {
        animator?.clean()
        stateController.state = AppState.defaultState()
//        messageController?.clean()
    }

    func cleanupTargetControllers() {
//        locationManager = nil
        cleanWebController()
        cleanARKController()
//        cleanOverlay()
    }

    func cleanARKController() {
        CLEAN_VIEW(v: arkLayerView)
        arkController = nil
    }

    func cleanWebController() {
        webController?.clean()
//        CLEAN_VIEW(v: webLayerView)
        webController = nil
    }
    
//    func cleanOverlay() {
//        overlayController?.clean()
//        CLEAN_VIEW(v: hotLayerView)
//        overlayController = nil
//    }

    
    // MARK: MemoryWarning
    
    func processMemoryWarning() {
        stateController.saveDidReceiveMemoryWarning(onURL: webController?.lastURL)
        cleanupCommonControllers()
        cleanupTargetControllers()
        setupTargetControllers()
    }

    // MARK: Data
    
    func commonData() -> [AnyHashable : Any] {
        var dictionary = [AnyHashable : Any]()

        if let aData = arkController?.getARKData() {
            dictionary = aData
        }

        return dictionary
    }

    func sendARKData() {
        webController?.sendARData(arkController?.getARKData() ?? [:])
    }

    func sendComputerVisionData() -> Bool {
        if let data = arkController?.getComputerVisionData() {
            webController?.sendComputerVisionData(data)
            return true
        }
        return false
    }

    func sendNativeTime() {
        guard let currentFrame = arkController?.currentFrameTimeInMilliseconds() else { return }
        webController?.sendNativeTime(currentFrame)
    }

    // MARK: Web
    
    func showWebError(_ error: NSError?) {
        guard let error = error else { return }
        if error.code == INTERNET_OFFLINE_CODE {
            stateController.setShowMode(.nothing)
            stateController.saveNotReachable(onURL: webController?.lastURL)
//            messageController?.showMessageAboutConnectionRequired()
        } else if error.code == USER_CANCELLED_LOADING_CODE {
            // Desired behavior is similar to Safari, i.e. no alerts or messages presented upon user-initiated cancel
        } else {
//            messageController?.showMessageAboutWebError(error, withCompletion: { reload in
//                
//                if reload {
//                    self.loadURL(nil)
//                } else {
//                    self.stateController.applyOnMessageShowMode()
//                }
//            })
        }
    }

    func loadURL(_ url: String?) {
        if url == nil {
            webController?.reload()
        } else {
            webController?.loadURL(url)
        }

        stateController.setWebXR(false)
    }

    func handleOnWatchAR(withRequest request: [AnyHashable : Any], initialLoad: Bool, grantedPermissionsBlock: ResultBlock?) {
        weak var blockSelf: WebXRPlugin? = self
        let accessString = self.commandDelegate.settings["webxrauthorization"] as? String
        print("AUTH: \(accessString ?? "")")
        var access: WebXRAuthorizationState
        
        switch accessString ?? "" {
            case "denied":
                access = .denied
            case "lite":
                access = .lite
            case "videoCameraAccess":
                access = .videoCameraAccess
            case "worldSensing":
                access = .worldSensing
            default:
                access = .minimal
        }
        
        if initialLoad {
            arkController?.computerVisionDataEnabled = false
            stateController.state.userGrantedSendingComputerVisionData = false
            stateController.state.userGrantedSendingWorldStateData = .notDetermined
            stateController.state.sendComputerVisionData = false
            stateController.state.askedComputerVisionData = false
            stateController.state.askedWorldStateData = false
        }
        
        guard let url = webController?.webView?.url else {
            grantedPermissionsBlock?([ "error" : "no web page loaded, should not happen"])
            return
        }
        arkController?.controller.previewingSinglePlane = false
        if let arController = arkController?.controller as? ARKMetalController {
            arController.focusedPlane = nil
        } else if let arController = arkController?.controller as? ARKSceneKitController {
            arController.focusedPlane = nil
        }

        stateController.state.numberOfTimesSendNativeTimeWasCalled = 0
        stateController.setARRequest(request) { () -> () in
            if request[WEB_AR_CV_INFORMATION_OPTION] as? Bool ?? false {
//                blockSelf?.messageController?.showMessageAboutEnteringXR(.videoCameraAccess, authorizationGranted: { access in
                    
                    blockSelf?.arkController?.geometryArrays = blockSelf?.stateController.state.geometryArrays ?? false
                    blockSelf?.stateController.state.askedComputerVisionData = true
                    blockSelf?.stateController.state.askedWorldStateData = true
                    let grantedCameraAccess = access == .videoCameraAccess ? true : false
                    let grantedWorldAccess = (access == .videoCameraAccess || access == .worldSensing || access == .lite) ? true : false
                    
                    blockSelf?.arkController?.computerVisionDataEnabled = grantedCameraAccess
                    
                    // Approving computer vision data implicitly approves the world sensing data
                    blockSelf?.arkController?.webXRAuthorizationStatus = access
                    
                    blockSelf?.stateController.state.userGrantedSendingComputerVisionData = grantedCameraAccess
                    blockSelf?.stateController.state.userGrantedSendingWorldStateData = access
                    
                    switch access {
                    case .minimal, .lite, .worldSensing, .videoCameraAccess:
                        blockSelf?.stateController.setWebXR(true)
                    default:
                        blockSelf?.stateController.setWebXR(false)
                    }
                    blockSelf?.webController?.userGrantedWebXRAuthorizationState(access)
                    let permissions = [
                        "cameraAccess": grantedCameraAccess,
                        "worldAccess": grantedWorldAccess,
                        "webXRAccess": blockSelf?.stateController.state.webXR ?? false
                    ]
                    grantedPermissionsBlock?(permissions)
//                }, url: url)
            } else if request[WEB_AR_WORLD_SENSING_DATA_OPTION] as? Bool ?? false {
//                blockSelf?.messageController?.showMessageAboutEnteringXR(.worldSensing, authorizationGranted: { access in
                    
                    blockSelf?.arkController?.geometryArrays = blockSelf?.stateController.state.geometryArrays ?? false
                    blockSelf?.stateController.state.askedWorldStateData = true
                    blockSelf?.arkController?.webXRAuthorizationStatus = access
                    blockSelf?.stateController.state.userGrantedSendingWorldStateData = access
                    let grantedWorldAccess = (access == .worldSensing || access == .lite) ? true : false
                    
                    switch access {
                    case .minimal, .lite, .worldSensing, .videoCameraAccess:
                        blockSelf?.stateController.setWebXR(true)
                    default:
                        blockSelf?.stateController.setWebXR(false)
                    }
                    
                    blockSelf?.webController?.userGrantedWebXRAuthorizationState(access)
                    let permissions = [
                        "cameraAccess": false,
                        "worldAccess": grantedWorldAccess,
                        "webXRAccess": blockSelf?.stateController.state.webXR ?? false
                    ]
                    grantedPermissionsBlock?(permissions)
                    
                    if access == .lite {
                        blockSelf?.arkController?.controller.previewingSinglePlane = true
                        if blockSelf?.stateController.state.shouldShowLiteModePopup ?? false {
                            blockSelf?.stateController.state.shouldShowLiteModePopup = false
                        }
                    }
//                }, url: url)
            } else {
                // if neither is requested, we'll request .minimal WebXR authorization!
//                blockSelf?.messageController?.showMessageAboutEnteringXR(.minimal, authorizationGranted: { access in
                    
                    blockSelf?.arkController?.geometryArrays = blockSelf?.stateController.state.geometryArrays ?? false
                    blockSelf?.arkController?.webXRAuthorizationStatus = access
                    
                    switch access {
                    case .minimal, .lite, .worldSensing, .videoCameraAccess:
                        blockSelf?.stateController.setWebXR(true)
                    case .denied, .notDetermined:
                        blockSelf?.stateController.setWebXR(false)
                    }
                    
                    blockSelf?.webController?.userGrantedWebXRAuthorizationState(access)
                    let permissions = [
                        "cameraAccess": false,
                        "worldAccess": false,
                        "webXRAccess": blockSelf?.stateController.state.webXR ?? false
                    ]
                    grantedPermissionsBlock?(permissions)
                    
                    if access == .lite {
                        blockSelf?.arkController?.controller.previewingSinglePlane = true
                        if blockSelf?.stateController.state.shouldShowLiteModePopup ?? false {
                            blockSelf?.stateController.state.shouldShowLiteModePopup = false
                        }
                    }
//                }, url: url)
            }
        }
    }
    
    func CLEAN_VIEW(v: UIView) {
        for view in v.subviews {
            view.removeFromSuperview()
        }
    }
    
    @objc private func chooseSinglePlaneAction() {
        arkController?.controller.previewingSinglePlane = false
        
        if let deferredHitTest = deferredHitTest {
            let array = arkController?.hitTestNormPoint(CGPoint(x: deferredHitTest.1, y: deferredHitTest.2), types: deferredHitTest.0)
            deferredHitTest.3(array)
            self.deferredHitTest = nil
        }
        
        let videoCamAccess = stateController.state.aRRequest[WEB_AR_CV_INFORMATION_OPTION] as? Bool ?? false
        let worldSensing = stateController.state.aRRequest[WEB_AR_WORLD_SENSING_DATA_OPTION] as? Bool ?? false
        if videoCamAccess || worldSensing {
            if let arController = arkController?.controller as? ARKMetalController {
                guard let chosenPlane = arController.focusedPlane else { return }
                if let anchorIdentifier = arController.planes.someKey(forValue: chosenPlane) {
                    let allFrameAnchors = arkController?.session.currentFrame?.anchors
                    let anchor = allFrameAnchors?.filter { $0.identifier == anchorIdentifier }.first
                    if let anchor = anchor {
                        let addedAnchorDictionary = arkController?.createDictionary(for: anchor)
                        arkController?.addedAnchorsSinceLastFrame.add(addedAnchorDictionary ?? [:])
                        arkController?.objects[anchor.identifier.uuidString] = addedAnchorDictionary
                    }
                }
            } else if let arController = arkController?.controller as? ARKSceneKitController {
                guard let chosenPlane = arController.focusedPlane else { return }
                if let anchorIdentifier = arController.planes.someKey(forValue: chosenPlane) {
                    let allFrameAnchors = arkController?.session.currentFrame?.anchors
                    let anchor = allFrameAnchors?.filter { $0.identifier == anchorIdentifier }.first
                    if let anchor = anchor {
                        let addedAnchorDictionary = arkController?.createDictionary(for: anchor)
                        arkController?.addedAnchorsSinceLastFrame.add(addedAnchorDictionary ?? [:])
                        arkController?.objects[anchor.identifier.uuidString] = addedAnchorDictionary
                    }
                }
            }
        }
    }
    
//    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
//        var axis: NSLayoutConstraint.Axis
//        chooseSinglePlaneButtonVerticalConstraint.constant = view.frame.height / 4
//        if view.traitCollection.verticalSizeClass == .compact {
//            messageController?.requestXRPermissionsVC?.stackViewWidthConstraint.constant = 584
//            axis = NSLayoutConstraint.Axis.horizontal
//        } else {
//            messageController?.requestXRPermissionsVC?.stackViewWidthConstraint.constant = 284
//            axis = NSLayoutConstraint.Axis.vertical
//        }
//        messageController?.requestXRPermissionsVC?.stackView?.axis = axis
//    }
}

extension ARCamera.TrackingState {
    var presentationString: String {
        switch self {
        case .notAvailable:
            return "Tracking is unavailable"
        case .normal:
            return ""
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "Limited tracking\nToo much camera movement"
            case .insufficientFeatures:
                return "Limited tracking\nNot enough surface detail"
            case .initializing:
                return "Initializing AR Session"
            case .relocalizing:
                return "Relocalizing\nSlowly scan the space around you"
            }
        }
    }
    var recommendation: String? {
        switch self {
        case .limited(.excessiveMotion):
            return "Try slowing down your movement, or reset the session."
        case .limited(.insufficientFeatures):
            return "Try pointing at a flat surface, or reset the session."
        default:
            return nil
        }
    }
}

class appDelegate {
    class Logger {
        let error = { NSLog("WEBXR PLUGIN ERROR : %@", $0) }
        let debug = { NSLog("WEBXR PLUGIN DEBUG : %@", $0) }
        let warning  = { NSLog("WEBXR PLUGIN WARN : %@", $0)  }
    }
    let logger = Logger()
}
