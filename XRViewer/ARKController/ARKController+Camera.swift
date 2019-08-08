@objc extension ARKController {
    
    // MARK: - Camera Device
    
    func setupDeviceCamera() {
        device = AVCaptureDevice.default(for: .video)
        
        if device == nil {
            appDelegate().logger.error("Camera device is NIL")
            return
        }
        
        do {
            try device.lockForConfiguration()
        } catch {
            appDelegate().logger.error("Camera lock error")
            return
        }
        
        if device.isFocusModeSupported(.continuousAutoFocus) {
            appDelegate().logger.debug("AVCaptureFocusModeContinuousAutoFocus Supported")
            device.focusMode = .continuousAutoFocus
        }
        
        if device.isFocusPointOfInterestSupported {
            appDelegate().logger.debug("FocusPointOfInterest Supported")
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }
        
        if device.isSmoothAutoFocusSupported {
            appDelegate().logger.debug("SmoothAutoFocus Supported")
            device.isSmoothAutoFocusEnabled = true
        }
        
        device.unlockForConfiguration()
    }
    
    // MARK: - Camera Button
    
    /**
     Removes all the anchors in the current session.
     
     If the current session is not of class ARFaceTrackingConfiguration, create a
     ARFaceTrackingConfiguration and run the session with it.
     
     Otherwise, create an ARWorldTrackingConfiguration, add the images that were not detected
     in the previous ARWorldTrackingConfiguration session, and run the session.
     */
    func switchCameraButtonTapped(_ state: AppState) { // numberOfTrackedImages: Int) {
        guard let currentFrame = session.currentFrame else { return }
        for anchor in currentFrame.anchors {
            session.remove(anchor: anchor)
        }
        
        if !(configuration is ARFaceTrackingConfiguration) {
            let faceTrackingConfiguration = ARFaceTrackingConfiguration()
            configuration = faceTrackingConfiguration
            runSession(with: state)
        } else {
            let worldTrackingConfiguration = ARWorldTrackingConfiguration()
            worldTrackingConfiguration.planeDetection = [.horizontal, .vertical]
            
            // Configure all the active images that weren't detected in the previous back camera session
            let undetectedImageNames = detectionImageActivationPromises.allKeys
            var newDetectionImages = Set<ARReferenceImage>()
            for imageName: String in undetectedImageNames as? [String] ?? [] {
                if let referenceImage = referenceImageMap[imageName] as? ARReferenceImage {
                    _ = newDetectionImages.insert(referenceImage)
                }
            }
            worldTrackingConfiguration.detectionImages = newDetectionImages
            configuration = worldTrackingConfiguration
            runSession(with: state)
        }
    }
    
    // MARK: - Helpers
    
    class func supportsARFaceTrackingConfiguration() -> Bool {
        return ARFaceTrackingConfiguration.isSupported
    }
}
