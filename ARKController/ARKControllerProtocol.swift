@objc protocol ARKControllerProtocol: NSObjectProtocol {
    init(sesion session: ARSession?, size: CGSize)
    func update(_ session: ARSession?)
    func clean()
    func getRenderView() -> UIView!
    func hitTest(_ point: CGPoint, with type: ARHitTestResult.ResultType) -> [Any]?
    // Commented during conversion of ARKSceneKitController to Swift, appears unused
    //- (id)currentHitTest;
    func setHitTestFocus(_ point: CGPoint)
    func setShowMode(_ mode: ShowMode)
    func setShowOptions(_ options: ShowOptions)
    func cameraProjectionTransform() -> matrix_float4x4
    var previewingSinglePlane: Bool { get set }
    var focusedPlane: PlaneNode? { get set }
    var planes: [UUID : PlaneNode] { get set }
}
