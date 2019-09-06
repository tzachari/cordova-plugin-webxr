import Foundation
import WebKit


typealias ResultBlock = ([AnyHashable : Any]?) -> Void
typealias ResultArrayBlock = ([Any]?) -> Void
typealias ImageDetectedBlock = ([AnyHashable : Any]?) -> Void
typealias ActivateDetectionImageCompletionBlock = (Bool, String?, [AnyHashable : Any]?) -> Void
typealias CreateDetectionImageCompletionBlock = (Bool, String?) -> Void
typealias GetWorldMapCompletionBlock = (Bool, String?, [AnyHashable : Any]?) -> Void
typealias SetWorldMapCompletionBlock = (Bool, String?) -> Void
typealias WebCompletion = (Any?, Error?) -> Void

class WebController: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    @objc var onInitAR: (([AnyHashable : Any]?) -> Void)?
    @objc var onError: ((Error?) -> Void)?
    @objc var loadURL: ((String?) -> Void)?
    @objc var onJSUpdateData: (() -> [AnyHashable : Any])?
    @objc var onRemoveObjects: (([Any]) -> Void)?
    @objc var onSetUI: (([AnyHashable : Any]?) -> Void)?
    @objc var onHitTest: ((Int, CGFloat, CGFloat, @escaping ResultArrayBlock) -> Void)?
    @objc var onAddAnchor: ((String?, [AnyHashable: Any]?, @escaping ResultBlock) -> Void)?
    @objc var onStartLoad: (() -> Void)?
    @objc var onFinishLoad: (() -> Void)?
    @objc var onDebugButtonToggled: ((Bool) -> Void)?
    var onGeometryArraysSet: ((Bool) -> Void)?
    @objc var onSettingsButtonTapped: (() -> Void)?
    @objc var onWatchAR: (([AnyHashable : Any]) -> Void)?
    @objc var onRequestSession: (([AnyHashable: Any], @escaping ResultBlock) -> Void)?
    var onJSFinishedRendering: (() -> Void)?
    @objc var onComputerVisionDataRequested: (() -> Void)?
    @objc var onStopAR: (() -> Void)?
    @objc var onResetTrackingButtonTapped: (() -> Void)?
    @objc var onSwitchCameraButtonTapped: (() -> Void)?
    @objc var onShowPermissions: (() -> Void)?
    @objc var onStartSendingComputerVisionData: (() -> Void)?
    @objc var onStopSendingComputerVisionData: (() -> Void)?
    var onSetNumberOfTrackedImages: ((Int) -> Void)?
    @objc var onAddImageAnchor: (([AnyHashable : Any]?, @escaping ImageDetectedBlock) -> Void)?
    @objc var onActivateDetectionImage: ((String?, @escaping ActivateDetectionImageCompletionBlock) -> Void)?
    @objc var onDeactivateDetectionImage: ((String, @escaping CreateDetectionImageCompletionBlock) -> Void)?
    @objc var onDestroyDetectionImage: ((String, @escaping CreateDetectionImageCompletionBlock) -> Void)?
    @objc var onCreateDetectionImage: (([AnyHashable : Any], @escaping CreateDetectionImageCompletionBlock) -> Void)?
    @objc var onGetWorldMap: ((@escaping GetWorldMapCompletionBlock) -> Void)?
    @objc var onSetWorldMap: (([AnyHashable : Any], @escaping SetWorldMapCompletionBlock) -> Void)?
    @objc var animator: Animator?
    @objc weak var webViewTopAnchorConstraint: NSLayoutConstraint?
    @objc var webViewLeftAnchorConstraint: NSLayoutConstraint?
    @objc var webViewRightAnchorConstraint: NSLayoutConstraint?
    @objc var lastXRVisitedURL = ""

    @objc weak var webView: WKWebView?
    private weak var contentController: WKUserContentController?
    private var transferCallback = ""
    @objc var lastURL = ""
    private var documentReadyState = ""
    
    @objc init(withWebView wv: WKWebView) {
        super.init()
        
        setupWebView(withWebView: wv)
        setupWebContent()
        setupWebUI()
    }
    
    deinit {
        appDelegate().logger.debug("WebController dealloc")
    }

    @objc func viewWillTransition(to size: CGSize) {
        layout()

        // This message is not being used by the polyfyill
        // [self callWebMethod:WEB_AR_IOS_VIEW_WILL_TRANSITION_TO_SIZE_MESSAGE param:NSStringFromCGSize(size) webCompletion:debugCompletion(@"viewWillTransitionToSize")];
    }

    @objc func loadURL(_ theUrl: String?) {
        goFullScreen()

        var url: URL?
        if theUrl?.hasPrefix("http://") ?? false || theUrl?.hasPrefix("https://") ?? false || theUrl?.hasPrefix("file://") ?? false {
            url = URL(string: theUrl ?? "")
        } else {
            url = URL(string: "https://\(theUrl ?? "")")
        }

        if url != nil {
            let scheme = url?.scheme

            if scheme != nil && WKWebView.handlesURLScheme(scheme ?? "") {
                var r: URLRequest? = nil
                if let anUrl = url {
                    r = URLRequest(url: anUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 60)
                }

                URLCache.shared.removeAllCachedResponses()

                if let aR = r {
                    webView?.load(aR)
                }

                self.lastURL = url?.absoluteString ?? ""
                return
            }
        }
        //if onError
        onError?(nil)
    }

    @objc func reload() {
        let url = lastURL
        loadURL(url)
    }

    @objc func clean() {
        cleanWebContent()

        webView?.stopLoading()

        webView?.configuration.processPool = WKProcessPool()
        URLCache.shared.removeAllCachedResponses()
    }

    @objc func setup(forWebXR webXR: Bool) {
        DispatchQueue.main.async(execute: {
            let webViewTopAnchorConstraintConstant: Float = webXR ? 0.0 : Float(Constant.urlBarHeight())
            self.webViewTopAnchorConstraint?.constant = CGFloat(webViewTopAnchorConstraintConstant)
            self.webView?.superview?.setNeedsLayout()
            self.webView?.superview?.layoutIfNeeded()
            let backColor = webXR ? UIColor.clear : UIColor.white
            self.webView?.superview?.backgroundColor = backColor
        })
    }

    @objc func showDebug(_ showDebug: Bool) {
        callWebMethod(WEB_AR_IOS_SHOW_DEBUG, paramJSON: [WEB_AR_UI_DEBUG_OPTION: showDebug ? true : false], webCompletion: debugCompletion(name: "showDebug"))
    }

    @objc func wasARInterruption(_ interruption: Bool) {
        let message = interruption ? WEB_AR_IOS_START_RECORDING_MESSAGE : WEB_AR_IOS_INTERRUPTION_ENDED_MESSAGE

        callWebMethod(message, param: "", webCompletion: debugCompletion(name: "ARinterruption"))
    }

    @objc func didBackgroundAction(_ background: Bool) {
        let message = background ? WEB_AR_IOS_DID_MOVE_BACK_MESSAGE : WEB_AR_IOS_WILL_ENTER_FOR_MESSAGE

        callWebMethod(message, param: "", webCompletion: debugCompletion(name: "backgroundAction"))
    }

    @objc func didChangeARTrackingState(_ state: String?) {
        callWebMethod(WEB_AR_IOS_TRACKING_STATE_MESSAGE, param: state, webCompletion: debugCompletion(name: "arkitDidChangeTrackingState"))
    }

    @objc func updateWindowSize() {
        let size: CGSize? = webView?.frame.size
        let sizeDictionary = [WEB_AR_IOS_SIZE_WIDTH_PARAMETER: size?.width ?? 0, WEB_AR_IOS_SIZE_HEIGHT_PARAMETER: size?.height ?? 0]
        callWebMethod(WEB_AR_IOS_WINDOW_RESIZE_MESSAGE, paramJSON: sizeDictionary, webCompletion: debugCompletion(name: WEB_AR_IOS_WINDOW_RESIZE_MESSAGE))
    }

    func didReceiveMemoryWarning() {
        callWebMethod(WEB_AR_IOS_DID_RECEIVE_MEMORY_WARNING_MESSAGE, param: "", webCompletion: debugCompletion(name: "iosDidReceiveMemoryWarning"))
    }

    @objc func sendARData(_ data: [AnyHashable : Any]) {
        if transferCallback != ""  {
            callWebMethod(transferCallback, paramJSON: data, webCompletion: nil)
        }
    }

    @objc func didReceiveError(error: NSError) {
        let errorDictionary = [WEB_AR_IOS_ERROR_DOMAIN_PARAMETER: error.domain, WEB_AR_IOS_ERROR_CODE_PARAMETER: error.code, WEB_AR_IOS_ERROR_MESSAGE_PARAMETER: error.localizedDescription] as [String : Any]
        callWebMethod(WEB_AR_IOS_ERROR_MESSAGE, paramJSON: errorDictionary, webCompletion: debugCompletion(name: WEB_AR_IOS_ERROR_MESSAGE))
    }

    @objc func sendComputerVisionData(_ computerVisionData: [AnyHashable : Any]) {
        callWebMethod("onComputerVisionData", paramJSON: computerVisionData, webCompletion: { param, error in
            if error != nil {
                print("Error onComputerVisionData: \(error?.localizedDescription ?? "")")
            }
        })
    }

    @objc func sendNativeTime(_ nativeTime: TimeInterval) {
        print("Sending native time: \(nativeTime)")
        let jsonData = ["nativeTime": nativeTime]
        callWebMethod("setNativeTime", paramJSON: jsonData, webCompletion: { param, error in
            if error != nil {
                print("Error setNativeTime: \(error?.localizedDescription ?? "")")
            }
        })
    }

    @objc func userGrantedWebXRAuthorizationState(_ access: WebXRAuthorizationState) {
        // This may change, in one of two ways:
        // - should probably switch this to one method that updates all aspects of the state we want
        // the page to know
        // - may want to remove entirely: do we even need to notify the page what the current state is?
        switch access {
        case .videoCameraAccess:
            callWebMethod(WEB_AR_IOS_USER_GRANTED_CV_DATA, paramJSON: ["granted": true], webCompletion: debugCompletion(name: WEB_AR_IOS_USER_GRANTED_CV_DATA))
            callWebMethod(WEB_AR_IOS_USER_GRANTED_WORLD_SENSING_DATA, paramJSON: ["granted": false], webCompletion: debugCompletion(name: WEB_AR_IOS_USER_GRANTED_WORLD_SENSING_DATA))
        case .worldSensing, .lite:
            callWebMethod(WEB_AR_IOS_USER_GRANTED_CV_DATA, paramJSON: ["granted": false], webCompletion: debugCompletion(name: WEB_AR_IOS_USER_GRANTED_CV_DATA))
            callWebMethod(WEB_AR_IOS_USER_GRANTED_WORLD_SENSING_DATA, paramJSON: ["granted": true], webCompletion: debugCompletion(name: WEB_AR_IOS_USER_GRANTED_WORLD_SENSING_DATA))
        case .notDetermined, .minimal, .denied:
            callWebMethod(WEB_AR_IOS_USER_GRANTED_CV_DATA, paramJSON: ["granted": false], webCompletion: debugCompletion(name: WEB_AR_IOS_USER_GRANTED_CV_DATA))
            callWebMethod(WEB_AR_IOS_USER_GRANTED_WORLD_SENSING_DATA, paramJSON: ["granted": false], webCompletion: debugCompletion(name: WEB_AR_IOS_USER_GRANTED_WORLD_SENSING_DATA))
        }
    }

    func goHome() {
        print("going home")
        let homeURL = UserDefaults.standard.string(forKey: Constant.homeURLKey())
        if homeURL != nil && !(homeURL == "") {
            loadURL(homeURL)
        } else {
            loadURL(WEB_URL)
        }
    }

    // MARK: WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        weak var blockSelf: WebController? = self
        guard let messageBody = message.body as? [String: Any] else { return }
        if message.name == WEB_AR_INIT_MESSAGE {
            let params = [
                WEB_IOS_DEVICE_UUID_OPTION: UIDevice.current.identifierForVendor?.uuidString ?? 0,
                WEB_IOS_IS_IPAD_OPTION: UIDevice.current.userInterfaceIdiom == .pad,
                WEB_IOS_SYSTEM_VERSION_OPTION: UIDevice.current.systemVersion,
                WEB_IOS_SCREEN_SCALE_OPTION: UIScreen.main.nativeScale,
                WEB_IOS_SCREEN_SIZE_OPTION: NSStringFromCGSize(UIScreen.main.nativeBounds.size)
            ] as [String : Any]

            appDelegate().logger.debug("Init AR send - \(params.debugDescription)")
            guard let name = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            callWebMethod(name, paramJSON: params, webCompletion: { param, error in

                if error == nil {
                    appDelegate().logger.debug("Init AR Success")
                    guard let arRequestOption = messageBody[WEB_AR_REQUEST_OPTION] as? [String: Any] else { return }
                    guard let arUIOption = arRequestOption[WEB_AR_UI_OPTION] as? [String: Any] else { return }
                    let geometryArrays = arRequestOption[WEB_AR_GEOMETRY_ARRAYS] as? Bool ?? false
                    blockSelf?.onGeometryArraysSet?(geometryArrays)
                    blockSelf?.onInitAR?(arUIOption)
                } else {
                    appDelegate().logger.debug("Init AR Error")
                    blockSelf?.onError?(error)
                }
            })
        } else if message.name == WEB_AR_INJECT_POLYFILL {
            let scriptBundle = Bundle(for: WebController.self)
            let scriptURL = scriptBundle.path(forResource: "webxrPolyfill", ofType: "js")
            let scriptContent = try? String(contentsOfFile: scriptURL ?? "", encoding: .utf8)
            let userScript = WKUserScript(source: scriptContent ?? "", injectionTime: .atDocumentStart, forMainFrameOnly: true)
            contentController?.addUserScript(userScript)
        } else if message.name == WEB_AR_LOAD_URL_MESSAGE {
            loadURL?(messageBody[WEB_AR_URL_OPTION] as? String)
        } else if message.name == WEB_AR_START_WATCH_MESSAGE {
            self.transferCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String ?? ""

            onWatchAR?(messageBody[WEB_AR_REQUEST_OPTION] as? [AnyHashable: Any] ?? [:])
        } else if message.name == WEB_AR_REQUEST_MESSAGE {
            guard let requestSessionCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            guard let transferCallback = messageBody[WEB_AR_DATA_CALLBACK_OPTION] as? String else {
                var responseDictionary = [AnyHashable : Any]()
                responseDictionary["error"] = "not data_callback parameter"
                blockSelf?.callWebMethod(requestSessionCallback, paramJSON: responseDictionary, webCompletion: debugCompletion(name: "requestSession"))
                return
            }
            self.transferCallback = transferCallback
            onRequestSession?(messageBody[WEB_AR_REQUEST_OPTION] as? [AnyHashable: Any] ?? [:], { permissions in
                blockSelf?.callWebMethod(requestSessionCallback, paramJSON: permissions, webCompletion: debugCompletion(name: "onRequestSession"))
            })
        } else if message.name == WEB_AR_ON_JS_UPDATE_MESSAGE {
            onJSFinishedRendering?()
        } else if message.name == WEB_AR_STOP_WATCH_MESSAGE {
            self.transferCallback = ""

            onStopAR?()
            guard let name = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            callWebMethod(name, param: "", webCompletion: nil)
        } else if message.name == WEB_AR_SET_UI_MESSAGE {
            onSetUI?(messageBody)
        } else if message.name == WEB_AR_HIT_TEST_MESSAGE {
            guard let hitCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            let type = Int(messageBody[WEB_AR_TYPE_OPTION] as? Int ?? 0)
            let x = CGFloat(messageBody[WEB_AR_X_POSITION_OPTION] as? CGFloat ?? 0.0)
            let y = CGFloat(messageBody[WEB_AR_Y_POSITION_OPTION] as? CGFloat ?? 0.0)

            onHitTest?(type, x, y, { results in
                blockSelf?.callWebMethod(hitCallback, paramJSON: results, webCompletion: debugCompletion(name: "onHitTest"))
            })
        } else if message.name == WEB_AR_ADD_ANCHOR_MESSAGE {
            guard let hitCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            let name = messageBody[WEB_AR_UUID_OPTION] as? String
            guard let transform = messageBody[WEB_AR_TRANSFORM_OPTION] as? [AnyHashable: Any] else {
                var responseDictionary = [AnyHashable : Any]()
                responseDictionary["error"] = "invalid transform parameter"
                blockSelf?.callWebMethod(hitCallback, paramJSON: responseDictionary, webCompletion: debugCompletion(name: "onAddAnchor"))
                return
            }
            onAddAnchor?(name, transform, { results in
                blockSelf?.callWebMethod(hitCallback, paramJSON: results, webCompletion: debugCompletion(name: "onAddAnchor"))
            })
        } else if message.name == WEB_AR_REQUEST_CV_DATA_MESSAGE {
            onComputerVisionDataRequested?()
        } else if message.name == WEB_AR_START_SENDING_CV_DATA_MESSAGE {
            onStartSendingComputerVisionData?()
        } else if message.name == WEB_AR_STOP_SENDING_CV_DATA_MESSAGE {
            onStopSendingComputerVisionData?()
        } else if message.name == WEB_AR_REMOVE_ANCHORS_MESSAGE {
            guard let anchorIDs = message.body as? [Any] else { return }
            onRemoveObjects?(anchorIDs)
        } else if message.name == WEB_AR_ADD_IMAGE_ANCHOR {
            let imageAnchorInfoDictionary = messageBody
            guard let createImageAnchorCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            onAddImageAnchor?(imageAnchorInfoDictionary, { imageAnchor in
                blockSelf?.callWebMethod(createImageAnchorCallback, paramJSON: imageAnchor, webCompletion: nil)
            })
        } else if message.name == WEB_AR_TRACKED_IMAGES_MESSAGE {
            let numberOfTrackedImages = messageBody[WEB_AR_NUMBER_OF_TRACKED_IMAGES_OPTION] as? Int ?? 0
            onSetNumberOfTrackedImages?(numberOfTrackedImages)
        } else if message.name == WEB_AR_CREATE_IMAGE_ANCHOR_MESSAGE {
            let imageAnchorInfoDictionary = messageBody
            guard let createDetectionImageCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            onCreateDetectionImage?(imageAnchorInfoDictionary, { success, errorString in
                var responseDictionary = [String : Any]()
                responseDictionary["created"] = success
                if errorString != nil {
                    responseDictionary["error"] = errorString
                }
                blockSelf?.callWebMethod(createDetectionImageCallback, paramJSON: responseDictionary, webCompletion: nil)
            })
        } else if message.name == WEB_AR_ACTIVATE_DETECTION_IMAGE_MESSAGE {
            let imageAnchorInfoDictionary = messageBody
            let imageName = imageAnchorInfoDictionary[WEB_AR_DETECTION_IMAGE_NAME_OPTION] as? String
            guard let activateDetectionImageCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            onActivateDetectionImage?(imageName, { success, errorString, imageAnchor in
                var responseDictionary = [AnyHashable : Any]()
                responseDictionary["activated"] = success
                if errorString != nil {
                    responseDictionary["error"] = errorString ?? ""
                } else {
                    if let anAnchor = imageAnchor {
                        responseDictionary["imageAnchor"] = anAnchor
                    }
                }
                blockSelf?.callWebMethod(activateDetectionImageCallback, paramJSON: responseDictionary, webCompletion: nil)
            })
        } else if message.name == WEB_AR_DEACTIVATE_DETECTION_IMAGE_MESSAGE {
            let imageAnchorInfoDictionary = messageBody
            guard let deactivateDetectionImageCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            guard let imageName = imageAnchorInfoDictionary[WEB_AR_DETECTION_IMAGE_NAME_OPTION] as? String else {
                var responseDictionary = [AnyHashable : Any]()
                responseDictionary["error"] = "invalid image name parameter"
                blockSelf?.callWebMethod(deactivateDetectionImageCallback, paramJSON: responseDictionary, webCompletion: debugCompletion(name: "onDeactivateImage"))
                return
            }

            onDeactivateDetectionImage?(imageName, { success, errorString in
                var responseDictionary = [AnyHashable : Any]()
                responseDictionary["deactivated"] = success
                if errorString != nil {
                    responseDictionary["error"] = errorString ?? ""
                }
                blockSelf?.callWebMethod(deactivateDetectionImageCallback, paramJSON: responseDictionary, webCompletion: debugCompletion(name: "onDeactivateImage"))
            })
        } else if message.name == WEB_AR_DESTROY_DETECTION_IMAGE_MESSAGE {
            let imageAnchorInfoDictionary = messageBody
            guard let destroyDetectionImageCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            guard let imageName = imageAnchorInfoDictionary[WEB_AR_DETECTION_IMAGE_NAME_OPTION] as? String else {
                var responseDictionary = [AnyHashable : Any]()
                responseDictionary["error"] = "invalid image name parameter"
                blockSelf?.callWebMethod(destroyDetectionImageCallback, paramJSON: responseDictionary, webCompletion: debugCompletion(name: "onDestroyDetectionImage"))
                return
            }
            onDestroyDetectionImage?(imageName, { success, errorString in
                var responseDictionary = [AnyHashable : Any]()
                responseDictionary["destroyed"] = success
                if errorString != nil {
                    responseDictionary["error"] = errorString ?? ""
                }
                blockSelf?.callWebMethod(destroyDetectionImageCallback, paramJSON: responseDictionary, webCompletion: debugCompletion(name: "onDestroyDetectionImage"))
            })
        } else if message.name == WEB_AR_GET_WORLD_MAP_MESSAGE {
            guard let getWorldMapCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            onGetWorldMap?({ success, errorString, worldMap in
                var responseDictionary = [AnyHashable : Any]()
                responseDictionary["saved"] = success
                if errorString != nil {
                    responseDictionary["error"] = errorString ?? ""
                }
                if worldMap != nil {
                    if let aMap = worldMap {
                        responseDictionary["worldMap"] = aMap
                    }
                }
                blockSelf?.callWebMethod(getWorldMapCallback, paramJSON: responseDictionary, webCompletion: nil)
            })
        } else if message.name == WEB_AR_SET_WORLD_MAP_MESSAGE {
            let worldMapInfoDictionary = messageBody
            guard let setWorldMapCallback = messageBody[WEB_AR_CALLBACK_OPTION] as? String else { return }
            onSetWorldMap?(worldMapInfoDictionary, { success, errorString in
                var responseDictionary = [AnyHashable : Any]()
                responseDictionary["loaded"] = success
                if errorString != nil {
                    responseDictionary["error"] = errorString ?? ""
                }
                blockSelf?.callWebMethod(setWorldMapCallback, paramJSON: responseDictionary, webCompletion: nil)
            })
        } else {
            appDelegate().logger.error("Unknown message: \(message.body) ,for name: \(message.name)")
        }

    }

    func callWebMethod(_ name: String, param: String?, webCompletion completion: WebCompletion?) {
        let jsonData = param != nil ? try? JSONSerialization.data(withJSONObject: [param], options: []) : Data()
        callWebMethod(name, jsonData: jsonData, webCompletion: completion)
    }

    func callWebMethod(_ name: String, paramJSON: Any?, webCompletion completion: WebCompletion?) {
        var jsonData: Data? = nil
        if let aJSON = paramJSON {
            jsonData = paramJSON != nil ? try? JSONSerialization.data(withJSONObject: aJSON, options: []) : Data()
        }
        callWebMethod(name, jsonData: jsonData, webCompletion: completion)
    }

    func callWebMethod(_ name: String?, jsonData: Data?, webCompletion completion: WebCompletion?) {
        assert(name != nil, " Web Massage name is nil !")

        var jsString: String? = nil
        if let aData = jsonData {
            jsString = String(data: aData, encoding: .utf8)
        }
        let jsScript = "\(name ?? "")(\(jsString ?? ""))"

        webView?.evaluateJavaScript(jsScript, completionHandler: completion)
    }

    // MARK: WKUIDelegate, WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let navigation = navigation {
            appDelegate().logger.debug("didStartProvisionalNavigation - \(navigation.debugDescription)\n on thread \(Thread.current.description)")
        }

        self.webView?.addObserver(self as NSObject, forKeyPath: "estimatedProgress", options: .new, context: nil)
        documentReadyState = ""

        onStartLoad?()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        appDelegate().logger.debug("didFinishNavigation - \(navigation.debugDescription)")
        //    NSString* loadedURL = [[[self webView] URL] absoluteString];
        //    [self setLastURL:loadedURL];
        //
        //    [[NSUserDefaults standardUserDefaults] setObject:loadedURL forKey:LAST_URL_KEY];
        //
        //    [self onFinishLoad]();
        //
        //    [[self barView] finishLoading:[[[self webView] URL] absoluteString]];
        //    [[self barView] setBackEnabled:[[self webView] canGoBack]];
        //    [[self barView] setForwardEnabled:[[self webView] canGoForward]];
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if error._domain == "WebKitErrorDomain", let info = error._userInfo as? [String:Any], let url = info[NSURLErrorFailingURLStringErrorKey],
            let urlString = url as? String, urlString.hasPrefix("file:"), urlString.hasSuffix("/") {
            // Redirect fix to get default HTML page for file path URLs
            // TODO: Verify this is needed - thought it worked w/o this before; may have broke something elsewhere?
            loadURL(urlString + "index.html")
        } else {
            appDelegate().logger.error("Web Error (didFailProvisional) - \(error)")
        }

        if self.webView?.observationInfo != nil {
            self.webView?.removeObserver(self, forKeyPath: "estimatedProgress")
        } else {
            print("No Observers Found on WebView in WebController didFailProvisionalNavigation Check")
        }

        if shouldShowError(error: error as NSError) {
            onError?(error)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        appDelegate().logger.error("Web Error (didFail) - \(error)")

        if self.webView?.observationInfo != nil {
            self.webView?.removeObserver(self as NSObject, forKeyPath: "estimatedProgress")
        } else {
            print("No Observers Found on WebView in WebController didFail Check")
        } 

        if shouldShowError(error: error as NSError) {
            onError?(error)
        }
    }

    func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
        return false
    }

    // MARK: Private

    func goFullScreen() {
        webViewTopAnchorConstraint?.constant = 0.0
    }

    func shouldShowError(error: NSError) -> Bool {
        return error.code > 600 || error.code < 200
    }

    func layout() {
        webView?.layoutIfNeeded()
    }

    func setupWebUI() {
        webView?.autoresizesSubviews = true

        webView?.allowsLinkPreview = false
        webView?.isOpaque = false
        webView?.backgroundColor = UIColor.clear
        webView?.isUserInteractionEnabled = true
        webView?.scrollView.bounces = false
        webView?.scrollView.bouncesZoom = false
    }

    func setupWebContent() {
        contentController?.add(self, name: WEB_AR_INIT_MESSAGE)
        contentController?.add(self, name: WEB_AR_INJECT_POLYFILL)
        contentController?.add(self, name: WEB_AR_START_WATCH_MESSAGE)
        contentController?.add(self, name: WEB_AR_REQUEST_MESSAGE)
        contentController?.add(self, name: WEB_AR_STOP_WATCH_MESSAGE)
        contentController?.add(self, name: WEB_AR_ON_JS_UPDATE_MESSAGE)
        contentController?.add(self, name: WEB_AR_LOAD_URL_MESSAGE)
        contentController?.add(self, name: WEB_AR_SET_UI_MESSAGE)
        contentController?.add(self, name: WEB_AR_HIT_TEST_MESSAGE)
        contentController?.add(self, name: WEB_AR_ADD_ANCHOR_MESSAGE)
        contentController?.add(self, name: WEB_AR_REQUEST_CV_DATA_MESSAGE)
        contentController?.add(self, name: WEB_AR_START_SENDING_CV_DATA_MESSAGE)
        contentController?.add(self, name: WEB_AR_STOP_SENDING_CV_DATA_MESSAGE)
        contentController?.add(self, name: WEB_AR_REMOVE_ANCHORS_MESSAGE)
        contentController?.add(self, name: WEB_AR_ADD_IMAGE_ANCHOR_MESSAGE)
        contentController?.add(self, name: WEB_AR_TRACKED_IMAGES_MESSAGE)
        contentController?.add(self, name: WEB_AR_CREATE_IMAGE_ANCHOR_MESSAGE)
        contentController?.add(self, name: WEB_AR_ACTIVATE_DETECTION_IMAGE_MESSAGE)
        contentController?.add(self, name: WEB_AR_DEACTIVATE_DETECTION_IMAGE_MESSAGE)
        contentController?.add(self, name: WEB_AR_DESTROY_DETECTION_IMAGE_MESSAGE)
        contentController?.add(self, name: WEB_AR_GET_WORLD_MAP_MESSAGE)
        contentController?.add(self, name: WEB_AR_SET_WORLD_MAP_MESSAGE)
    }

    func cleanWebContent() {
        contentController?.removeScriptMessageHandler(forName: WEB_AR_INIT_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_INJECT_POLYFILL)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_START_WATCH_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_REQUEST_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_STOP_WATCH_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_ON_JS_UPDATE_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_LOAD_URL_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_SET_UI_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_HIT_TEST_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_ADD_ANCHOR_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_REQUEST_CV_DATA_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_START_SENDING_CV_DATA_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_STOP_SENDING_CV_DATA_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_REMOVE_ANCHORS_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_ADD_IMAGE_ANCHOR_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_TRACKED_IMAGES_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_CREATE_IMAGE_ANCHOR_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_ACTIVATE_DETECTION_IMAGE_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_DEACTIVATE_DETECTION_IMAGE_MESSAGE)
        contentController?.removeScriptMessageHandler(forName: WEB_AR_DESTROY_DETECTION_IMAGE_MESSAGE)
    }

    func appVersion() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    
    func build() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
    }
    
    func versionBuild() -> String? {
        let version = appVersion()
        let build = self.build()
        
        var versionBuild = "v\(version ?? "")"
        
        if version != build {
            versionBuild = "\(versionBuild)(\(build ?? ""))"
        }
        
        return versionBuild
    }

    func setupWebView(withWebView wv: WKWebView) {
        let scriptBundle = Bundle.main
        let scriptURL = scriptBundle.path(forResource: "webxrShim", ofType: "js")
        let scriptContent = try? String(contentsOfFile: scriptURL ?? "", encoding: .utf8)
        print(String(format: "size of webxrShim.js: %ld", scriptContent?.count ?? 0))
        
        let userScript = WKUserScript(source: scriptContent ?? "", injectionTime: .atDocumentStart, forMainFrameOnly: true)
        self.contentController = wv.configuration.userContentController
        self.contentController?.addUserScript(userScript)
    
        wv.evaluateJavaScript("navigator.userAgent", completionHandler: { ( base, error ) in
            wv.customUserAgent = (base as? String ?? "") + " Mobile WebXRViewer/1.17"
        })
        
        wv.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        wv.navigationDelegate = self
        wv.uiDelegate = self
        self.webView = wv
    }

    func setupWebView(withRootView rootView: UIView?) {
        let conf = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        let version = versionBuild() ?? "unknown"
        conf.applicationNameForUserAgent = " Mobile WebXRViewer/" + version

        let standardUserDefaults = UserDefaults.standard
        // Check if we are supposed to be exposing WebXR.
        if standardUserDefaults.bool(forKey: Constant.exposeWebXRAPIKey()) {
            let scriptBundle = Bundle(for: WebController.self)
            let scriptURL = scriptBundle.path(forResource: "webxrShim", ofType: "js")
            let scriptContent = try? String(contentsOfFile: scriptURL ?? "", encoding: .utf8)

            print(String(format: "size of webxrShim.js: %ld", scriptContent?.count ?? 0))

            let userScript = WKUserScript(source: scriptContent ?? "", injectionTime: .atDocumentStart, forMainFrameOnly: true)

            contentController.addUserScript(userScript)
        }
        conf.userContentController = contentController
        self.contentController = contentController

        let pref = WKPreferences()
        pref.javaScriptEnabled = true
        conf.preferences = pref

        conf.processPool = WKProcessPool()

        conf.allowsInlineMediaPlayback = true
        conf.allowsAirPlayForMediaPlayback = true
        conf.allowsPictureInPictureMediaPlayback = true
        conf.mediaTypesRequiringUserActionForPlayback = []

        let wv = WKWebView(frame: rootView?.bounds ?? CGRect.zero, configuration: conf)
        rootView?.addSubview(wv)
        wv.translatesAutoresizingMaskIntoConstraints = false

        guard let rootTopAnchor = rootView?.topAnchor else { return }
        guard let rootBottomAnchor = rootView?.bottomAnchor else { return }
        guard let rootLeftAnchor = rootView?.leftAnchor else { return }
        guard let rootRightAnchor = rootView?.rightAnchor else { return }
        
        let webViewTopAnchorConstraint: NSLayoutConstraint = wv.topAnchor.constraint(equalTo: rootTopAnchor)
        self.webViewTopAnchorConstraint = webViewTopAnchorConstraint
        webViewTopAnchorConstraint.isActive = true
        let webViewLeftAnchorConstraint: NSLayoutConstraint = wv.leftAnchor.constraint(equalTo: rootLeftAnchor)
        self.webViewLeftAnchorConstraint = webViewLeftAnchorConstraint
        webViewLeftAnchorConstraint.isActive = true
        let webViewRightAnchorConstraint: NSLayoutConstraint = wv.rightAnchor.constraint(equalTo: rootRightAnchor)
        self.webViewRightAnchorConstraint = webViewRightAnchorConstraint
        webViewRightAnchorConstraint.isActive = true

        wv.bottomAnchor.constraint(equalTo: rootBottomAnchor).isActive = true

        wv.scrollView.contentInsetAdjustmentBehavior = .never

        wv.navigationDelegate = self
        wv.uiDelegate = self
        webView = wv
    }

    func documentDidBecomeInteractive() {
        print("documentDidBecomeInteractive")
        let loadedURL = webView?.url?.absoluteString

        lastURL = loadedURL ?? ""
        UserDefaults.standard.set(loadedURL, forKey: LAST_URL_KEY)

        onFinishLoad?()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        weak var blockSelf: WebController? = self

        if (keyPath == "estimatedProgress") && (object as? WKWebView) == blockSelf?.webView {
            blockSelf?.webView?.evaluateJavaScript("document.readyState", completionHandler: { readyState, error in
                DispatchQueue.main.async(execute: {
                    print("Estimated progress: \(blockSelf?.webView?.estimatedProgress ?? 0.0)")
                    print("document.readyState: \(readyState ?? "")")

                    if ((readyState as? String == "interactive") && !(blockSelf?.documentReadyState == "interactive")) || ((blockSelf?.webView?.estimatedProgress ?? 0.0) >= 1.0) {
                        if blockSelf?.webView?.observationInfo != nil {
                            if let aSelf = blockSelf {
                                blockSelf?.webView?.removeObserver(aSelf as NSObject, forKeyPath: "estimatedProgress")
                            }
                            blockSelf?.documentDidBecomeInteractive()
                        } else {
                            print("No Observers Found on WebView in WebController Override observeValue Check")
                        }
                    }

                    blockSelf?.documentReadyState = readyState as? String ?? ""
                })
            })
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

@inline(__always) private func debugCompletion(name: String) -> WebCompletion {
    return { param, error in
        if error == nil {
            appDelegate().logger.debug("\(name) : success")
        } else {
            appDelegate().logger.debug("\(name) : error")
        }
    }
}
