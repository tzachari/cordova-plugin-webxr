# Cordova WebXR Plugin

Add augmented reality content to your app using the WebXR Device API ([Mozilla's version](https://github.com/mozilla/webxr-polyfill/)).  

This is intended to support the same content as Mozilla's [iOS WebXR Viewer](https://apps.apple.com/us/app/webxr-viewer/id1295998056).


## Installation

Install using the Apache Cordova command line:

    cordova plugin add cordova-plugin-webxr

This plugin can only be used on [ARKit-compatible devices](https://www.apple.com/ios/augmented-reality/#ac-globalfooter) and requires an iOS Deployment Target of 12.0 or higher. 
Make sure to adjust the project config.xml accordingly, e.g:

    <platform name="ios">
      <preference name="deployment-target" value="12.0.0" />
    </platform>


## Try It Out

To quickly test some interactive AR content, set the default source in the project's config.xml to Mozilla's [example site](https://webxr-ios.webxrexperiments.com/):

    <content src="https://webxr-ios.webxrexperiments.com/" />

The source code for the examples can be found in Mozilla's [webxr-ios-js repo](https://github.com/MozillaReality/webxr-ios-js/tree/develop/examples)


## Options

The plugin provides a set of a configurable options:

- **WEBXR_AUTHORIZATION**: Sets what is shared with a page that uses the WebXR API
  - `denied`: Shares no world sensing data and no video
  - `minimal` (default): Shares minimal world sensing data, but no video
  - `lite`: Shares one real world plane & enables face-based experiences, but no video
  - `worldSensing`: Shares full world sensing data, but no video
  - `videoCameraAccess`: Shares full world sensing data and video feed

- **GRAPHICS_FRAMEWORK**: Specifies which graphics framework to use
  - `sceneKit` (default): Uses [SceneKit](https://developer.apple.com/scenekit/)
  - `metal`: Uses [Metal](https://developer.apple.com/metal/) (experimental)

To set these options, specify them when adding the plugin, e.g:

    cordova plugin add cordova-plugin-webxr --variable GRAPHICS_FRAMEWORK=metal

Or add them within the plugin's tag in config.xml, e.g:

    <plugin name="cordova-plugin-webxr" spec="^1.17.0">
        <variable name="WEBXR_AUTHORIZATION" value="lite" />
    </plugin>

There are also some additional parameters that can be overridden:

- **CAMERA_USAGE_DESCRIPTION**: Describes why camera access is required. Default: `This app uses the camera for augmented reality`

- **PRODUCT_MODULE_NAME**: If the Product Module Name in the iOS Target Build Settings differs from the Cordova project name (e.g. when embedding a Cordova WebView into an existing app), the module name must be passed to this variable. If omitted, the app may not build.


## NOTE: Mozilla WebXR ≠ W3C WebXR (yet)
Mozilla is in the process of aligning [their version of the API](https://github.com/mozilla/webxr-polyfill/) with the [official draft W3C spec](https://www.w3.org/TR/webxr/).
As such, some features are currently broken.
This plugin will be updated as the API stabilizes.

## Dependencies

- **iOS 12 / ARKit 2**: The plugin can only be used on ARKit-compatible devices and requires an iOS Deployment Target of 12.0 or higher. 

- **Swift 4**: The iOS source code assumes Swift 4.0. It will automatically install `cordova-plugin-add-swift-support`, if it is not already present.

- **WKWebView**: The plugin requires WKWebView. It will automatically install `cordova-plugin-wkwebview-engine`, if not already in use.


## Credits

This plugin is based on the source for Mozilla's WebXR Viewer ([webxr-ios@d3485fb](https://github.com/mozilla-mobile/webxr-ios/tree/d3485fb65fae52bcfb925cf5feeecca0f66f6f47))