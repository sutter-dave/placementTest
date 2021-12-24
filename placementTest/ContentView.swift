//
//  ContentView.swift
//  ModelPickerApp
//
//  Created by Dave Sutter on 12/10/21.
//

import SwiftUI
import RealityKit
import ARKit
//import SceneKit

var imageSet = false
var detectedPlanes = [UUID:ARPlaneAnchor]()
var aPlane:ARPlaneAnchor?

let unitX = simd_float4(1,0,0,0)
let unitY = simd_float4(0,1,0,0)
let unitZ = simd_float4(0,0,1,0)
let zeroVector = simd_float4(0,0,0,1)

struct ContentView : View {
    @State private var isPlacementEnabled = false
    @State private var selectedModel: Model?
    @State private var modelConfirmedForPlacement: Model?
    @State private var parentAnchorForAddition: ARAnchor? = nil
    
    var models: [Model] = {
        let fileManager = FileManager.default
        
        guard let path = Bundle.main.resourcePath, let files = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }
        
        var availableModels: [Model] = []
        for fileName in files where fileName.hasSuffix("usdz") {
            let modelName = fileName.replacingOccurrences(of: ".usdz", with: "")
            
            let model = Model(modelName: modelName)
            availableModels.append(model)
        }
        
        return availableModels
    }()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(modelConfirmedForPlacement: self.$modelConfirmedForPlacement,
                            parentAnchorForAddition: self.$parentAnchorForAddition,
                            models: self.models)
            
            if self.isPlacementEnabled {
                PlacementButtonsView(isPlacementEnabled: self.$isPlacementEnabled,
                                     selectedModel: self.$selectedModel,
                                     modelConfirmedForPlacement: self.$modelConfirmedForPlacement,
                                     models: models)
            }
            else {
                ModelPickerView(isPlacementEnabled: self.$isPlacementEnabled,
                                selectedModel: self.$selectedModel,
                                models: models)
            }
            
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var modelConfirmedForPlacement: Model?
    @Binding var parentAnchorForAddition: ARAnchor?
    var models: [Model]
    
    //FIRST VERSION OF MAKE UI VIEW WITH STANDARD AR VIEW
//    func makeUIView(context: Context) -> ARView {
//
//        let arView = ARView(frame: .zero)
//
//        //ar view configuration----
//        let config = ARWorldTrackingConfiguration()
//        config.planeDetection = [.horizontal, .vertical]
//        config.environmentTexturing = .automatic
//
//        //this is for if we have lidar scene reconstruction (he says)
//        if(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)) {
//            config.sceneReconstruction = .mesh
//            print("DEBUG: Enabling mesh scene reconstruction")
//        }
//
//        arView.session.run(config)
//        //---------------------
//
//        return arView
//
//    }
    
    //SECOND VERSION OF MAKE UI VIEW WITH FOCUS SQUARE
    func makeUIView(context: Context) -> ARView {
        let customARView = CustomARView(frame: .zero)
        customARView.anchorPlacer = self
        return customARView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        
        if let model = modelConfirmedForPlacement {
            
    
//dont reset session
//            if model.modelName == "fender_stratocaster" {
//                //model 0 selected - stop plane detection
//                if let customARView = uiView as? CustomARView {
//                    customARView.setupARView(enablePlaneDetection: false)
//                    print("Reconfig with no plane detection!")
//                }
//                else {
//                    print("Failed reconfig - incorrect ARView type!")
//                }
//
//            }
//            else
            if model.modelName == "toy_drummer" {
                //model 1 selected - print detected planes
                printPlanes()
                addPlanes(view: uiView)
                
//                if let planeAnchor = aPlane {
//                    print("Adding a plane instead of model 1")
//                    let meshResource = MeshResource.generatePlane(width: planeAnchor.extent[0], depth: planeAnchor.extent[1])
//                    let material = SimpleMaterial(color: SimpleMaterial.Color.cyan, isMetallic: true)
//                    let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
//
//                    let anchorEntity = AnchorEntity(plane: .any)
//                    anchorEntity.addChild(modelEntity.clone(recursive: true))
//                    uiView.scene.addAnchor(anchorEntity)
//                }
                
                
                //add the existing model to the plane location
//                if let modelEntity = model.modelEntity {
//                    for planeAnchor in detectedPlanes.values {
//                        let anchorEntity = AnchorEntity(world: planeAnchor.transform)
//
//                        print("detected plane transform: \(planeAnchor.transform)")
//                        print("new entity transform \(anchorEntity.transform)")
//
//                        anchorEntity.addChild(modelEntity.clone(recursive: true))
//                        uiView.scene.addAnchor(anchorEntity)
//                    }
//                }
                
//                for planeAnchor in detectedPlanes.values {
//                    let anchorEntity = AnchorEntity(world: planeAnchor.transform)
//
//                    let meshResource = MeshResource.generatePlane(width: planeAnchor.extent[0], depth: planeAnchor.extent[2])
//                    //let meshResource = MeshResource.generatePlane(width: 0.3, depth: 0.3)
//                    //let meshResource = MeshResource.generateSphere(radius: 0.3)
//                    let material = SimpleMaterial(color: SimpleMaterial.Color.cyan, isMetallic: true)
//                    let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
//
//                    anchorEntity.addChild(modelEntity.clone(recursive: true))
//                    uiView.scene.addAnchor(anchorEntity)
//                }
            }
            else if model.modelName == "condo" {
                placeModel(view: uiView, model: model)
            }
            else if model.modelName == "toy_robot_vintage" {
                placeModel(view: uiView, model: model)
            }
            else  {
                //just place the model if it is not one of the first two
                if let modelEntity = model.modelEntity {
                    let anchorEntity = AnchorEntity(plane: .any)
                    //NOTE - before we added the clone statement, it was adding the same model multiple times
                    //in which case it removed the old placement of the model. This fixes that by adding a clone of the model
                    anchorEntity.addChild(modelEntity.clone(recursive: true))
                    uiView.scene.addAnchor(anchorEntity)
                    print("DEBUG: place model - \(model.modelName)")
                }
                else {
                    print("DEBUG: Unable to place model - model entity not loaded - \(model.modelName)")
                }
            }
            
            DispatchQueue.main.async {
                self.modelConfirmedForPlacement = nil
            }
        }
        
        if let parentAnchor = parentAnchorForAddition {
            let model = self.models[1]
            
            if let modelEntity = model.modelEntity {
                let anchorEntity = AnchorEntity(anchor: parentAnchor)
                anchorEntity.addChild(modelEntity.clone(recursive: true))
                uiView.scene.addAnchor(anchorEntity)
                print("DEBUG: placed model on parent - \(model.modelName)")
                
                DispatchQueue.main.async {
                    self.parentAnchorForAddition = nil
                }
            }
        }
        
    }
    
    func placeAnchor(parentAnchor: ARAnchor) {
        DispatchQueue.main.async {
            self.parentAnchorForAddition = parentAnchor
        }
    }
    
    //==========
    func addPlanes(view: ARView) {
        for planeAnchor in detectedPlanes.values {
            placePlane(planeAnchor: planeAnchor, view: view)
        }
    }

    func placePlane(planeAnchor:ARPlaneAnchor, view: ARView) {
        
        //let meshResource = MeshResource.generatePlane(width: planeAnchor.extent[0], depth: planeAnchor.extent[1])
        let meshResource = createMeshFromPlaneVertices(vertices: planeAnchor.geometry.vertices)
        var material = PhysicallyBasedMaterial()
        let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
        
        let anchorEntity = AnchorEntity(world: planeAnchor.transform)
        
        print("detected plane transform: \(planeAnchor.transform)")
        print("new entity transform \(anchorEntity.transform)")
        
        anchorEntity.addChild(modelEntity)
        view.scene.addAnchor(anchorEntity)
    }
    
    func placeModel(view: ARView, model: Model) {
        let modelEntity = model.modelEntity!
        let transform = self.createObjectTransform()
        print("new transform: \(transform)")
        let anchorEntity = AnchorEntity(world: transform)
        anchorEntity.addChild(modelEntity)
        view.scene.addAnchor(anchorEntity)
    
    }
    
    func createObjectTransform() -> simd_float4x4 {
        if(detectedPlanes.count != 3) {
            print("three planes not found!")
        }
        
        var planeInfoArray = [PlaneInfo]()
        
        for planeAnchor in detectedPlanes.values {
            print("plane \(planeAnchor.identifier)")
            let localToWorld = planeAnchor.transform
            let worldToLocal = localToWorld.inverse
            
            print("transform: \(localToWorld)")
            print("inverse transform: \(worldToLocal)")
                  
            //==================
            //find plane normals
            //==================
            
            let worldNormal = simd_mul(localToWorld,unitY)
            
            print("plane normal: \(worldNormal)")
            
            //==================
            //find plane intersection vector
            //==================
            
            let yProjection = simd_mul(unitY,worldToLocal)
            
            print("y projection: \(yProjection)")
            
            planeInfoArray.append(PlaneInfo(
                localToWorld: localToWorld,
                worldToLocal: worldToLocal,
                worldNormal: worldNormal,
                yProjection: yProjection
            ))
        }
        
        //=============
        // Find the intersction of all three planes
        //=============
        let intersectionMatrix = simd_float4x4(
            planeInfoArray[0].yProjection,
            planeInfoArray[1].yProjection,
            planeInfoArray[2].yProjection,
            zeroVector
        ).transpose
        print("intersectionMatrix \(intersectionMatrix)")
        
        let intersectionVector = simd_mul(intersectionMatrix.inverse,zeroVector)
        print("intersection vector \(intersectionVector)")
        
        //check the intersection projected into each local coordinate system has y=0
        print("intersection test 0: \(simd_mul(planeInfoArray[0].worldToLocal,intersectionVector))")
        print("intersection test 1: \(simd_mul(planeInfoArray[1].worldToLocal,intersectionVector))")
        print("intersection test 2: \(simd_mul(planeInfoArray[2].worldToLocal,intersectionVector))")
        
        //================
        //identify the planes (clean this up! I think I can simplify it)
        //================
        var xIndex:Int = -1
        var yIndex:Int = -1
        var zIndex:Int = -1
        for index in (0..<3) {  //we need this to be three
            //let xProj = simd_dot(unitY,planeInfo.worldNormal)
            let yProj = simd_dot(unitY,planeInfoArray[index].worldNormal)
            //let zProj = simd_dot(unitY,planeInfo.worldNormal)
            
            //we expect this to be very close to 1, but we will use > .9
            if(yProj > 0.9) {
                if(yIndex == -1) {
                    yIndex = index
                }
                else {
                    print("repeat y value!")
                }
            }
        }
        
        //guess the x and z indices
        if(yIndex == 1) {
            xIndex = 0
            zIndex = 2
        }
        else if(yIndex == 2) {
            xIndex = 1
            zIndex = 0
        }
        else {
            xIndex = 2
            zIndex = 1
        }
        
        let det = simd_float4x4(
            planeInfoArray[0].worldNormal,
            planeInfoArray[1].worldNormal,
            planeInfoArray[2].worldNormal,
            zeroVector
        ).determinant
        print("determninant: \(det)")
        
        //if the determinant is negative we guessed wrong for x and z
        if(det < 0) {
            swap(&xIndex,&zIndex)
        }
        
        print("xIndex: \(xIndex), yIndex: \(yIndex), zIndex: \(zIndex), ")
        
        //===========
        //orthoganolize the normals
        //===========
        //tke y to be the y unit vector -
        let yNormal = unitY;
        
        let xNormal = projectOut(inputVector: planeInfoArray[xIndex].worldNormal, projectOut: yNormal)
        let zNormalTemp = projectOut(inputVector: planeInfoArray[zIndex].worldNormal, projectOut: yNormal)
        let zNormal = projectOut(inputVector: zNormalTemp, projectOut: xNormal)
        
        print("local y unit vector: \(yNormal)")
        print("local x unit vector: \(xNormal)")
        print("local z unit vector: \(zNormal)")
        
        let newLocalToWorld = createTransform(
            xNormal: xNormal,
            yNormal: yNormal,
            zNormal: zNormal,
            location: intersectionVector)
        
        return newLocalToWorld;
    }
 
    
    func projectOut(inputVector: simd_float4,projectOut: simd_float4) -> simd_float4 {
        let projection = simd_project(inputVector,projectOut)
        let unnormalized = simd_float4(
            inputVector[0] - projection[0],
            inputVector[1] - projection[1],
            inputVector[2] - projection[2],
            0
        )
        return simd_normalize(unnormalized)
    }
    
    func createTransform(xNormal: simd_float4, yNormal: simd_float4, zNormal: simd_float4, location: simd_float4) -> simd_float4x4 {
        
        //convert from model directions to local directions
        //model x direction maps to world z
        //model y direction maps to world x
        //model z direction maps to world y
        let modelToLocalDirections = simd_float4x4(
            unitZ,
            unitX,
            unitY,
            zeroVector
        )
        //convert model scale to local scale: inches to meters
        let scaleFactor:Float = 0.0254;
        let modelToLocalScale = simd_float4x4(diagonal: simd_float4(scaleFactor,scaleFactor,scaleFactor,Float(1)))
        
        //convert local coordinates to world coordinates
        let localToWorld = simd_float4x4(
            xNormal,
            yNormal,
            zNormal,
            location
        )
            
        //chain the transformations
        return simd_mul(localToWorld,simd_mul(modelToLocalScale,modelToLocalDirections))
    }
    
    
    
}

struct ModelPickerView: View {
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: Model?
    
    var models:[Model]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                ForEach(0..<self.models.count) { index in
                    Button(action: {
                        print("DEBUG: Model with name : \(self.models[index].modelName)")
                        
                        self.selectedModel = self.models[index]
                        self.isPlacementEnabled = true;
                    }) {
                        Image(uiImage: self.models[index].image)
                            .resizable()
                            .frame(height: 80)
                            .aspectRatio(1/1,contentMode: .fit)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.5))
    }

}

struct PlacementButtonsView: View {
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: Model?
    @Binding var modelConfirmedForPlacement: Model?
    
    var models:[Model]
    
    var body: some View {
        HStack {
            //cancel button
            Button(action: {
                print("DEBUG: Model placement canceled")
                resetPlacementParameters()
            }, label: {
                Image(systemName: "xmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.blue.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            })
            
            //confirm button
            Button(action: {
                print("DEBUG: Model placement confirmed")
                self.modelConfirmedForPlacement = self.selectedModel
                resetPlacementParameters()
            }, label: {
                Image(systemName: "checkmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.blue.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            })
            
        }
    }
    
    func resetPlacementParameters() {
        self.isPlacementEnabled = false;
        self.selectedModel = nil
    }
    
}

//=============================================
// This is the Custom AR View
class CustomARView: ARView, ARSessionDelegate {
    var anchorPlacer: ARViewContainer?
    
    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        
        //self.delegate = self
        //self.session.delegate = self
        
        self.setupARView(enablePlaneDetection: true)
    }
    
    @objc required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented!")
    }
    
    //(this is exactly the same config we did in the standard AR view version)
    func setupARView(enablePlaneDetection: Bool) {
        let config = ARWorldTrackingConfiguration()
        if enablePlaneDetection {
            config.planeDetection = [.horizontal, .vertical]
        }
        
        config.environmentTexturing = .automatic
        
        //this is for if we have lidar scene reconstruction (he says)
        if(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)) {
            config.sceneReconstruction = .mesh
            print("DEBUG: Enabling mesh scene reconstruction")
        }
        
        //IMAGE ANCHORS========
//        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
//            fatalError("Missing expected asset catalog resources.")
//        }
        
//        config.detectionImages = referenceImages
        //END IMAGE ANCHORS=========
        
        //self.delegate = self
        self.session.delegate = self

        //options added for image anchors
        self.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let imageAnchor = anchor as? ARImageAnchor {
                if !imageSet {
                    print("YES! An image anchor was added!")
                    imageSet = true;
                    
                    if let ap = self.anchorPlacer {
                        let parentAnchor = ARAnchor(anchor: imageAnchor)
                        ap.placeAnchor(parentAnchor: parentAnchor)
                    }
                }
                else {
                    print("image seen, but already set")
                }
            }
            else if let planeAnchor = anchor as? ARPlaneAnchor {
                if(detectedPlanes[planeAnchor.identifier] != nil) {
                    print("Plane updated found for \(planeAnchor.identifier)")
                }
                else {
                    print("New Plane found: \(planeAnchor.identifier)")
                }
                detectedPlanes[planeAnchor.identifier] = planeAnchor
                
                //============
                //grarb the first plane
                if aPlane == nil {
                    aPlane = planeAnchor
                }
                //=============
            }
            else {
                //print("a non-image anchor was added")
            }
            
        }
    }
}

func printPlanes() {
    for planeAnchor in detectedPlanes.values {
        printPlane(planeAnchor: planeAnchor)
    }
}

func printPlane(planeAnchor:ARPlaneAnchor) {
    print("ARPlaneAnchor ID: \(planeAnchor.identifier)")
    print("Alignment: \(planeAnchor.alignment)")
    print("Center: \(planeAnchor.center); Extent: \(planeAnchor.extent)")
    print("Transform: \(planeAnchor.transform)")
    print("Vertice count: \(planeAnchor.geometry.vertices.count)")
    for vertex in planeAnchor.geometry.vertices {
        print("\(vertex)")
    }
}

func createMeshFromPlaneVertices(vertices:[vector_float3]) -> MeshResource {
    
    //let xvertices:[vector_float3] = [[0,0,0],[0.1,0,-0.1],[0.1,0,0.1],[-0.1,0,-0.1],[-0.1,0,0.1]]
    var descr = MeshDescriptor()
    descr.positions = MeshBuffers.Positions(vertices)
    //descr.positions = MeshBuffers.Positions(xvertices)
    var orderArray = [UInt32]()
    //=== got to be a better way to do this
    
    for index in 2..<vertices.count {
        orderArray.append(0)
        orderArray.append(UInt32(index-1))
        orderArray.append(UInt32(index))
    }
    //let xorderArray:[UInt32] = [4,0,3,2,1,0]
    //=======
    descr.primitives = .triangles(orderArray)
    //descr.primitives = .triangles(xorderArray)
    
    return try! MeshResource.generate(from: [descr])
}

//END Custom AR View code
//==================================================

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
