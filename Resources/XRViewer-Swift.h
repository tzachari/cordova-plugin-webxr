
#if !defined(SWIFT_PASTE)
# define SWIFT_PASTE_HELPER(x, y) x##y
# define SWIFT_PASTE(x, y) SWIFT_PASTE_HELPER(x, y)
#endif
#if __has_attribute(noescape)
# define SWIFT_NOESCAPE __attribute__((noescape))
#else
# define SWIFT_NOESCAPE
#endif
#if __has_attribute(warn_unused_result)
# define SWIFT_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#else
# define SWIFT_WARN_UNUSED_RESULT
#endif
#if !defined(SWIFT_EXTENSION)
# define SWIFT_EXTENSION(M) SWIFT_PASTE(M##_Swift_, __LINE__)
#endif
#if !defined(OBJC_DESIGNATED_INITIALIZER)
# if __has_attribute(objc_designated_initializer)
#  define OBJC_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
# else
#  define OBJC_DESIGNATED_INITIALIZER
# endif
#endif
#if !defined(SWIFT_UNAVAILABLE)
# define SWIFT_UNAVAILABLE __attribute__((unavailable))
#endif
#if !defined(SWIFT_DEPRECATED_MSG)
# define SWIFT_DEPRECATED_MSG(...) __attribute__((deprecated(__VA_ARGS__)))
#endif


#define DDLogDebug(...) NSLog(__VA_ARGS__)
#define DDLogError(...) NSLog(__VA_ARGS__)


@class ARSession;
@class ARFrame;
@class ARAnchor;

@interface ARKController (SWIFT_EXTENSION(XRViewer)) <ARSessionDelegate>
- (void)session:(ARSession * _Nonnull)session didUpdateFrame:(ARFrame * _Nonnull)frame;
- (void)session:(ARSession * _Nonnull)session didAddAnchors:(NSArray<ARAnchor *> * _Nonnull)anchors;
- (void)session:(ARSession * _Nonnull)session didUpdateAnchors:(NSArray<ARAnchor *> * _Nonnull)anchors;
- (void)session:(ARSession * _Nonnull)session didRemoveAnchors:(NSArray<ARAnchor *> * _Nonnull)anchors;
@end


@class ARCamera;

@interface ARKController (SWIFT_EXTENSION(XRViewer)) <ARSessionObserver>
- (void)session:(ARSession * _Nonnull)session cameraDidChangeTrackingState:(ARCamera * _Nonnull)camera;
- (void)sessionWasInterrupted:(ARSession * _Nonnull)session;
- (void)sessionInterruptionEnded:(ARSession * _Nonnull)session;
- (void)session:(ARSession * _Nonnull)session didFailWithError:(NSError * _Nonnull)error;
- (BOOL)sessionShouldAttemptRelocalization:(ARSession * _Nonnull)session SWIFT_WARN_UNUSED_RESULT;
@end


@class ARReferenceImage;

@interface ARKController (SWIFT_EXTENSION(XRViewer))
- (ARReferenceImage * _Nullable)createReferenceImageFromDictionary:(NSDictionary * _Nonnull)referenceImageDictionary SWIFT_WARN_UNUSED_RESULT;
- (void)createRequestedDetectionImages;
- (void)createDetectionImage:(NSDictionary * _Nonnull)referenceImageDictionary completion:(DetectionImageCreatedCompletionType _Nonnull)completion;
- (void)_createDetectionImage:(NSDictionary * _Nonnull)referenceImageDictionary;
- (void)activateDetectionImage:(NSString * _Nullable)imageName completion:(void (^ _Nonnull)(BOOL, NSString * _Nullable, NSDictionary * _Nullable))completion;
- (void)deactivateDetectionImage:(NSString * _Nonnull)imageName completion:(SWIFT_NOESCAPE void (^ _Nonnull)(BOOL, NSString * _Nullable))completion;
- (void)destroyDetectionImage:(NSString * _Nonnull)imageName completion:(SWIFT_NOESCAPE void (^ _Nonnull)(BOOL, NSString * _Nullable))completion;
- (void)clearImageDetectionDictionaries;
- (void)updateBase64BuffersFrom:(CVPixelBufferRef _Nonnull)capturedImagePixelBuffer;
- (CGSize)downscaleByFactorOf2UntilLargestSideIsLessThan512AvoidingFractionalSides:(CGSize)originalSize SWIFT_WARN_UNUSED_RESULT;
- (NSString * _Nonnull)stringFor:(OSType)type SWIFT_WARN_UNUSED_RESULT;
- (void)logPixelBufferInfo:(CVPixelBufferRef _Nonnull)capturedImagePixelBuffer;
- (void)setNumberOfTrackedImages:(NSInteger)numberOfTrackedImages;
@end


@class ARWorldMap;

@interface ARKController (SWIFT_EXTENSION(XRViewer))
- (void)saveWorldMap;
- (void)_save:(ARWorldMap * _Nonnull)worldMap;
- (void)saveWorldMapInBackground;
- (void)loadSavedMap;
- (void)getWorldMap:(void (^ _Nonnull)(BOOL, NSString * _Nullable, NSDictionary * _Nullable))completion;
- (void)_getWorldMap;
- (void)setWorldMap:(NSDictionary * _Nonnull)worldMapDictionary completion:(void (^ _Nonnull)(BOOL, NSString * _Nullable))completion;
- (void)_setWorldMap:(ARWorldMap * _Nonnull)map;
- (NSData * _Nullable)getDecompressedData:(NSData * _Nonnull)compressed SWIFT_WARN_UNUSED_RESULT;
- (NSData * _Nullable)getCompressedData:(NSData * _Nullable)input SWIFT_WARN_UNUSED_RESULT;
- (void)printWorldMapInfo:(ARWorldMap * _Nonnull)worldMap;
- (ARWorldMap * _Nullable)dictToWorldMap:(NSDictionary * _Nonnull)worldMapDictionary SWIFT_WARN_UNUSED_RESULT;
- (BOOL)worldMappingAvailable SWIFT_WARN_UNUSED_RESULT;
- (BOOL)hasBackgroundWorldMap SWIFT_WARN_UNUSED_RESULT;
@end


@class NSDictionary;
@class ARFaceAnchor;
@class NSMutableDictionary;
@class ARFaceGeometry;
@class NSMutableArray;
@class ARPlaneGeometry;
@class ARPlaneAnchor;
@class NSArray;

@interface ARKController (SWIFT_EXTENSION(XRViewer))
- (void)updateDictionaryFor:(ARAnchor * _Nonnull)updatedAnchor;
- (NSDictionary * _Nonnull)createDictionaryFor:(ARAnchor * _Nonnull)addedAnchor SWIFT_WARN_UNUSED_RESULT;
- (void)addFaceAnchorData:(ARFaceAnchor * _Nonnull)faceAnchor toDictionary:(NSMutableDictionary * _Nonnull)faceAnchorDictionary;
- (void)addFaceGeometryData:(ARFaceGeometry * _Nonnull)faceGeometry toDictionary:(NSMutableDictionary * _Nonnull)geometryDictionary;
- (void)setBlendShapes:(NSDictionary * _Nonnull)blendShapes toArray:(NSMutableArray * _Nonnull)blendShapesArray;
- (void)updatePlaneGeometryData:(ARPlaneGeometry * _Nonnull)planeGeometry toDictionary:(NSMutableDictionary * _Nonnull)planeGeometryDictionary;
- (void)addGeometryData:(ARPlaneGeometry * _Nonnull)planeGeometry toDictionary:(NSMutableDictionary * _Nonnull)dictionary;
- (void)addPlaneAnchorData:(ARPlaneAnchor * _Nonnull)planeAnchor toDictionary:(NSMutableDictionary * _Nonnull)dictionary;
- (void)updatePlaneAnchorData:(ARPlaneAnchor * _Nonnull)planeAnchor toDictionary:(NSMutableDictionary * _Nonnull)planeAnchorDictionary;
- (void)removeAnchors:(NSArray * _Nonnull)anchorIDsToDelete;
- (void)removeDistantAnchors;
- (void)removeAllAnchors;
- (void)removeAllAnchorsExceptPlanes;
- (ARAnchor * _Nullable)getAnchorFromARKitAnchorID:(NSString * _Nonnull)arkitAnchorID SWIFT_WARN_UNUSED_RESULT;
- (ARAnchor * _Nullable)getAnchorFromUserAnchorID:(NSString * _Nonnull)userAnchorID SWIFT_WARN_UNUSED_RESULT;
- (NSArray * _Nonnull)currentAnchorsArray SWIFT_WARN_UNUSED_RESULT;
- (NSString * _Nonnull)anchorIDFor:(ARAnchor * _Nonnull)anchor SWIFT_WARN_UNUSED_RESULT;
- (BOOL)addAnchor:(NSString * _Nullable)userGeneratedAnchorID transformHash:(NSDictionary * _Nullable)transformHash SWIFT_WARN_UNUSED_RESULT;
- (BOOL)shouldSend:(ARAnchor * _Nonnull)anchor SWIFT_WARN_UNUSED_RESULT;
- (BOOL)anyPlaneAnchor:(NSArray<ARAnchor *> * _Nonnull)anchorArray SWIFT_WARN_UNUSED_RESULT;
@end


@class UIView;
enum ShowMode : NSInteger;
@class PlaneNode;

@protocol ARKControllerProtocol <NSObject>
- (nonnull instancetype)initWithSesion:(ARSession * _Nullable)session size:(CGSize)size;
- (void)update:(ARSession * _Nullable)session;
- (void)clean;
- (UIView * _Null_unspecified)getRenderView SWIFT_WARN_UNUSED_RESULT;
- (NSArray * _Nullable)hitTest:(CGPoint)point with:(ARHitTestResultType)type SWIFT_WARN_UNUSED_RESULT;
- (void)setHitTestFocus:(CGPoint)point;
- (void)setShowMode:(enum ShowMode)mode;
- (void)setShowOptions:(ShowOptions)options;
- (matrix_float4x4)cameraProjectionTransform SWIFT_WARN_UNUSED_RESULT;
@property (nonatomic) BOOL previewingSinglePlane;
@property (nonatomic, strong) PlaneNode * _Nullable focusedPlane;
@property (nonatomic, copy) NSDictionary<NSUUID *, PlaneNode *> * _Nonnull planes;
@end


@class MTKView;

@interface ARKMetalController : NSObject <MTKViewDelegate, ARKControllerProtocol>
@property (nonatomic) BOOL previewingSinglePlane;
@property (nonatomic, strong) PlaneNode * _Nullable focusedPlane;
@property (nonatomic, copy) NSDictionary<NSUUID *, PlaneNode *> * _Nonnull planes;
- (nonnull instancetype)initWithSesion:(ARSession * _Nullable)session size:(CGSize)size OBJC_DESIGNATED_INITIALIZER;
- (UIView * _Null_unspecified)getRenderView SWIFT_WARN_UNUSED_RESULT;
- (void)setHitTestFocus:(CGPoint)point;
- (NSArray * _Nullable)hitTest:(CGPoint)point with:(ARHitTestResultType)type SWIFT_WARN_UNUSED_RESULT;
- (matrix_float4x4)cameraProjectionTransform SWIFT_WARN_UNUSED_RESULT;
- (void)setShowMode:(enum ShowMode)mode;
- (void)setShowOptions:(ShowOptions)options;
- (void)clean;
- (void)update:(ARSession * _Nullable)session;
- (void)mtkView:(MTKView * _Nonnull)view drawableSizeWillChange:(CGSize)size;
- (void)drawInMTKView:(MTKView * _Nonnull)view;
- (nonnull instancetype)init SWIFT_UNAVAILABLE;
+ (nonnull instancetype)new SWIFT_DEPRECATED_MSG("-init is unavailable");
@end


@protocol SCNSceneRenderer;
@class SCNNode;

@interface ARKSceneKitController : NSObject <ARSCNViewDelegate, ARKControllerProtocol>
@property (nonatomic, copy) NSDictionary<NSUUID *, PlaneNode *> * _Nonnull planes;
@property (nonatomic) BOOL previewingSinglePlane;
@property (nonatomic, strong) PlaneNode * _Nullable focusedPlane;
- (nonnull instancetype)initWithSesion:(ARSession * _Nullable)session size:(CGSize)size OBJC_DESIGNATED_INITIALIZER;
- (void)update:(ARSession * _Nullable)session;
- (void)clean;
- (NSArray * _Nullable)hitTest:(CGPoint)point with:(ARHitTestResultType)type SWIFT_WARN_UNUSED_RESULT;
- (matrix_float4x4)cameraProjectionTransform SWIFT_WARN_UNUSED_RESULT;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer updateAtTime:(NSTimeInterval)time;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer didAddNode:(SCNNode * _Nonnull)node forAnchor:(ARAnchor * _Nonnull)anchor;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer willUpdateNode:(SCNNode * _Nonnull)node forAnchor:(ARAnchor * _Nonnull)anchor;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer didUpdateNode:(SCNNode * _Nonnull)node forAnchor:(ARAnchor * _Nonnull)anchor;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer didRemoveNode:(SCNNode * _Nonnull)node forAnchor:(ARAnchor * _Nonnull)anchor;
- (UIView * _Null_unspecified)getRenderView SWIFT_WARN_UNUSED_RESULT;
- (void)setHitTestFocus:(CGPoint)point;
- (void)setShowMode:(enum ShowMode)mode;
- (void)setShowOptions:(ShowOptions)options;
- (nonnull instancetype)init SWIFT_UNAVAILABLE;
+ (nonnull instancetype)new SWIFT_DEPRECATED_MSG("-init is unavailable");
@end


@interface Utils : NSObject
+ (UIInterfaceOrientation)getInterfaceOrientationFromDeviceOrientation SWIFT_WARN_UNUSED_RESULT;
- (nonnull instancetype)init OBJC_DESIGNATED_INITIALIZER;
@end
