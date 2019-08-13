# Cordova WebXR Plugin

Add augmented reality content to your app using the WebXR Device API (well, [Mozilla's version](https://github.com/mozilla/webxr-polyfill/)).  

This is intended to support all content that is viewable in [Mozilla's iOS WebXR Viewer](https://apps.apple.com/us/app/webxr-viewer/id1295998056).


## Installation

Install using the Apache Cordova command line:

    cordova plugin add cordova-plugin-webxr

This plugin can only be used on ARKit-compatible devices and requires an iOS Deployment Target of 12.0 or higher. 
Make sure to adjust the project config.xml accordingly, e.g:

    <platform name="ios">
      <preference name="deployment-target" value="12.0.0" />
    </platform>


## Try It Out

To test some interactive AR content, set the default source in the project's config.xml to [Mozilla's examples site](https://webxr-ios.webxrexperiments.com/):

    <content src="https://webxr-ios.webxrexperiments.com/" />

The source code for the examples can be found in Mozilla's [webxr-ios-js repo](https://github.com/MozillaReality/webxr-ios-js/tree/develop/examples)


## NOTE: Mozilla WebXR ≠ W3C WebXR (yet)
Mozilla's version of the API is substantially different from the W3C draft spec. 
They plan to align their's with the W3C spec once it has matured.


## Dependencies

- **iOS 12.0 / ARKit**: The plugin can only be used on ARKit-compatible devices and requires an iOS Deployment Target of 12.0 or higher. 

- **User Agent**: The plugin relies on the `AppendUserAgent` preference value. If you plan to override the value in config.xml, ensure it includes "WebXRViewer", e.g:<br/>
`<preference name="AppendUserAgent" value="WebXRViewer CustomUserAgentName" /> `

- **Swift Version**: The iOS source code assumes Swift 4.0. It will automatically install `cordova-plugin-add-swift-support`, if it is not already present.

- **WKWebView**: The plugin requires WKWebView. It will automatically install `cordova-plugin-wkwebview-engine`, if not already in use.


## Credits

This plugin is based on the source for Mozilla's WebXR Viewer ([webxr-ios@d3485fb](https://github.com/mozilla-mobile/webxr-ios/tree/d3485fb65fae52bcfb925cf5feeecca0f66f6f47))