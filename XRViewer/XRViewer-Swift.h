// XRViewer-Swift.h
// Replaces the expected auto-generated header in ARKController.m

@class ARSession;
@class ARFrame;
@class ARAnchor;

@interface ARKController (ARSessionDelegate) <ARSessionDelegate>
- (void)session:(ARSession * _Nonnull)session didUpdateFrame:(ARFrame * _Nonnull)frame;
- (void)session:(ARSession * _Nonnull)session didAddAnchors:(NSArray<ARAnchor *> * _Nonnull)anchors;
- (void)session:(ARSession * _Nonnull)session didUpdateAnchors:(NSArray<ARAnchor *> * _Nonnull)anchors;
- (void)session:(ARSession * _Nonnull)session didRemoveAnchors:(NSArray<ARAnchor *> * _Nonnull)anchors;
@end


@class ARCamera;

@interface ARKController (ARSessionObserver) <ARSessionObserver>
- (void)session:(ARSession * _Nonnull)session cameraDidChangeTrackingState:(ARCamera * _Nonnull)camera;
- (void)sessionWasInterrupted:(ARSession * _Nonnull)session;
- (void)sessionInterruptionEnded:(ARSession * _Nonnull)session;
- (void)session:(ARSession * _Nonnull)session didFailWithError:(NSError * _Nonnull)error;
- (BOOL)sessionShouldAttemptRelocalization:(ARSession * _Nonnull)session;
@end


@class ARReferenceImage;

@interface ARKController (Images)
- (ARReferenceImage * _Nullable)createReferenceImageFromDictionary:(NSDictionary * _Nonnull)referenceImageDictionary;
- (void)createRequestedDetectionImages;
- (void)createDetectionImage:(NSDictionary * _Nonnull)referenceImageDictionary completion:(DetectionImageCreatedCompletionType _Nonnull)completion;
- (void)_createDetectionImage:(NSDictionary * _Nonnull)referenceImageDictionary;
- (void)activateDetectionImage:(NSString * _Nullable)imageName completion:(void (^ _Nonnull)(BOOL, NSString * _Nullable, NSDictionary * _Nullable))completion;
- (void)deactivateDetectionImage:(NSString * _Nonnull)imageName completion:(void (^ _Nonnull)(BOOL, NSString * _Nullable))completion;
- (void)destroyDetectionImage:(NSString * _Nonnull)imageName completion:(void (^ _Nonnull)(BOOL, NSString * _Nullable))completion;
- (void)clearImageDetectionDictionaries;
- (void)updateBase64BuffersFrom:(CVPixelBufferRef _Nonnull)capturedImagePixelBuffer;
- (CGSize)downscaleByFactorOf2UntilLargestSideIsLessThan512AvoidingFractionalSides:(CGSize)originalSize;
- (NSString * _Nonnull)stringFor:(OSType)type;
- (void)logPixelBufferInfo:(CVPixelBufferRef _Nonnull)capturedImagePixelBuffer;
- (void)setNumberOfTrackedImages:(NSInteger)numberOfTrackedImages;
@end


@class ARWorldMap;

@interface ARKController (WorldMap)
- (void)saveWorldMap;
- (void)_save:(ARWorldMap * _Nonnull)worldMap;
- (void)saveWorldMapInBackground;
- (void)loadSavedMap;
- (void)getWorldMap:(void (^ _Nonnull)(BOOL, NSString * _Nullable, NSDictionary * _Nullable))completion;
- (void)_getWorldMap;
- (void)setWorldMap:(NSDictionary * _Nonnull)worldMapDictionary completion:(void (^ _Nonnull)(BOOL, NSString * _Nullable))completion;
- (void)_setWorldMap:(ARWorldMap * _Nonnull)map;
- (NSData * _Nullable)getDecompressedData:(NSData * _Nonnull)compressed;
- (NSData * _Nullable)getCompressedData:(NSData * _Nullable)input;
- (void)printWorldMapInfo:(ARWorldMap * _Nonnull)worldMap;
- (ARWorldMap * _Nullable)dictToWorldMap:(NSDictionary * _Nonnull)worldMapDictionary;
- (BOOL)worldMappingAvailable;
- (BOOL)hasBackgroundWorldMap;
@end


@class NSDictionary;
@class ARFaceAnchor;
@class NSMutableDictionary;
@class ARFaceGeometry;
@class NSMutableArray;
@class ARPlaneGeometry;
@class ARPlaneAnchor;
@class NSArray;

@interface ARKController (Anchors)
- (void)updateDictionaryFor:(ARAnchor * _Nonnull)updatedAnchor;
- (NSDictionary * _Nonnull)createDictionaryFor:(ARAnchor * _Nonnull)addedAnchor;
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
- (ARAnchor * _Nullable)getAnchorFromARKitAnchorID:(NSString * _Nonnull)arkitAnchorID;
- (ARAnchor * _Nullable)getAnchorFromUserAnchorID:(NSString * _Nonnull)userAnchorID;
- (NSArray * _Nonnull)currentAnchorsArray;
- (NSString * _Nonnull)anchorIDFor:(ARAnchor * _Nonnull)anchor;
- (BOOL)addAnchor:(NSString * _Nullable)userGeneratedAnchorID transformHash:(NSDictionary * _Nullable)transformHash;
- (BOOL)shouldSend:(ARAnchor * _Nonnull)anchor;
- (BOOL)anyPlaneAnchor:(NSArray<ARAnchor *> * _Nonnull)anchorArray;
@end


@class UIView;
enum ShowMode : NSInteger;
@class PlaneNode;

@protocol ARKControllerProtocol <NSObject>
- (nonnull instancetype)initWithSesion:(ARSession * _Nullable)session size:(CGSize)size;
- (void)update:(ARSession * _Nullable)session;
- (void)clean;
- (UIView * _Null_unspecified)getRenderView;
- (NSArray * _Nullable)hitTest:(CGPoint)point with:(ARHitTestResultType)type;
- (void)setHitTestFocus:(CGPoint)point;
- (void)setShowMode:(enum ShowMode)mode;
- (void)setShowOptions:(ShowOptions)options;
- (matrix_float4x4)cameraProjectionTransform;
@property (nonatomic) BOOL previewingSinglePlane;
@property (nonatomic, strong) PlaneNode * _Nullable focusedPlane;
@property (nonatomic, copy) NSDictionary<NSUUID *, PlaneNode *> * _Nonnull planes;
@end


@class MTKView;

@interface ARKMetalController : NSObject {} @end
@implementation ARKMetalController {} @end

@interface ARKMetalController (Swift) <MTKViewDelegate, ARKControllerProtocol>
@property (nonatomic) BOOL previewingSinglePlane;
@property (nonatomic, strong) PlaneNode * _Nullable focusedPlane;
@property (nonatomic, copy) NSDictionary<NSUUID *, PlaneNode *> * _Nonnull planes;
- (nonnull instancetype)initWithSesion:(ARSession * _Nullable)session size:(CGSize)size;
- (UIView * _Null_unspecified)getRenderView;
- (void)setHitTestFocus:(CGPoint)point;
- (NSArray * _Nullable)hitTest:(CGPoint)point with:(ARHitTestResultType)type;
- (matrix_float4x4)cameraProjectionTransform;
- (void)setShowMode:(enum ShowMode)mode;
- (void)setShowOptions:(ShowOptions)options;
- (void)clean;
- (void)update:(ARSession * _Nullable)session;
- (void)mtkView:(MTKView * _Nonnull)view drawableSizeWillChange:(CGSize)size;
- (void)drawInMTKView:(MTKView * _Nonnull)view;
- (nonnull instancetype)init;
+ (nonnull instancetype)new;
@end


@protocol SCNSceneRenderer;
@class SCNNode;

@interface ARKSceneKitController : NSObject {} @end
@implementation ARKSceneKitController {} @end

@interface ARKSceneKitController (Swift) <ARSCNViewDelegate, ARKControllerProtocol>
@property (nonatomic, copy) NSDictionary<NSUUID *, PlaneNode *> * _Nonnull planes;
@property (nonatomic) BOOL previewingSinglePlane;
@property (nonatomic, strong) PlaneNode * _Nullable focusedPlane;
- (nonnull instancetype)initWithSesion:(ARSession * _Nullable)session size:(CGSize)size;
- (void)update:(ARSession * _Nullable)session;
- (void)clean;
- (NSArray * _Nullable)hitTest:(CGPoint)point with:(ARHitTestResultType)type;
- (matrix_float4x4)cameraProjectionTransform;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer updateAtTime:(NSTimeInterval)time;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer didAddNode:(SCNNode * _Nonnull)node forAnchor:(ARAnchor * _Nonnull)anchor;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer willUpdateNode:(SCNNode * _Nonnull)node forAnchor:(ARAnchor * _Nonnull)anchor;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer didUpdateNode:(SCNNode * _Nonnull)node forAnchor:(ARAnchor * _Nonnull)anchor;
- (void)renderer:(id <SCNSceneRenderer> _Nonnull)renderer didRemoveNode:(SCNNode * _Nonnull)node forAnchor:(ARAnchor * _Nonnull)anchor;
- (UIView * _Null_unspecified)getRenderView;
- (void)setHitTestFocus:(CGPoint)point;
- (void)setShowMode:(enum ShowMode)mode;
- (void)setShowOptions:(ShowOptions)options;
- (nonnull instancetype)init;
+ (nonnull instancetype)new;
@end


@interface Utils : NSObject {} @end
@implementation Utils {} @end

@interface Utils (Swift)
+ (UIInterfaceOrientation)getInterfaceOrientationFromDeviceOrientation;
- (nonnull instancetype)init;
@end
