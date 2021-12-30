//
//  ContentView.swift
//  ModelPickerApp
//
//  Created by Dave Sutter on 12/10/21.
//

import SwiftUI
import RealityKit
import ARKit
import Combine

var detectedPlanes = [UUID:DetectedPlaneInfo]()

let unitX = simd_float4(1,0,0,0)
let unitY = simd_float4(0,1,0,0)
let unitZ = simd_float4(0,0,1,0)
let zeroVector = simd_float4(0,0,0,1)

var condoModel:Model? = nil

let modelInfo =  ModelInfo(
    name: "condo",
    modelOriginSketchupCM: simd_float3(4.378325,7.366,0),
    entryPoints: [
        EntryPointInfo(
            id: "Bedroom",
            entryPointSketchupCM: simd_float3(0,0,0),
            cornerNormalAlignment: [true,true,false]
        ),
        EntryPointInfo(
            id: "Living Room",
            entryPointSketchupCM: simd_float3(8.75665,12.29995,0),
            cornerNormalAlignment: [false,true,true]
        ),
    ]
)

//=========
var condoAnchorEntity:AnchorEntity? = nil
//=========

var externalScenes = [String:Entity]()
var externalInfo = [String:SceneInfo]()

var externalLoading = [String:Combine.AnyCancellable]()

//func handleEntityTap(_ entity:Entity?) {
//    if let e = entity {
//        print("Entity tapped: \(e.name)")
//    }
//}



struct ContentView : View {
    @State private var modelPlaced = false;
    @State private var isPlacementEnabled = false
    @State private var selectedEntryPoint: EntryPointInfo?
    @State private var entryPointConfirmedForPlacement: EntryPointInfo?
    
    init() {
        //load the building model
        condoModel = Model(modelName: modelInfo.name)
        
        //load the scenes
        loadUnanchoredScene(
            fileName: "Christmas",
            fileExtension: ".reality",
            sceneName: "ChristmasScene"
        )
        loadUnanchoredScene(
            fileName: "Random",
            fileExtension: ".reality",
            sceneName: "RandomScene"
        )
        let randomSceneInfo = SceneInfo(links: [
            "cylinder":"https://www.apogeejs.com"
        ])
        externalInfo["RandomScene"] = randomSceneInfo;
        loadUnanchoredScene(
            fileName: "BowlingScene",
            //fileExtension: ".rcproject",
            fileExtension: ".reality",
            sceneName: "BowlingScene"
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(entryPointConfirmedForPlacement: self.$entryPointConfirmedForPlacement,
                            modelPlaced: self.$modelPlaced)
            
            if !self.modelPlaced {
                if self.isPlacementEnabled {
                    PlacementButtonsView(isPlacementEnabled: self.$isPlacementEnabled,
                                         selectedEntryPoint: self.$selectedEntryPoint,
                                         entryPointConfirmedForPlacement: self.$entryPointConfirmedForPlacement)
                }
                else {
                    EntryPointPickerView(isPlacementEnabled: self.$isPlacementEnabled,
                                    selectedEntryPoint: self.$selectedEntryPoint)
                }
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var entryPointConfirmedForPlacement: EntryPointInfo?
    @Binding var modelPlaced: Bool
    
    func makeUIView(context: Context) -> ARView {
        let customARView = CustomARView(frame: .zero)
        customARView.viewContainer = self
        return customARView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        
        if let entryPointInfo = entryPointConfirmedForPlacement {
            
            let modelPlaced = placeModel(
                view: uiView,
                model: condoModel!,
                modelInfo: modelInfo,
                entryPointInfo: entryPointInfo)
            
            if(modelPlaced) {
                removeDetectedPlanes(view: uiView)
                print("planes removed!")
            }
            
            DispatchQueue.main.async {
                self.entryPointConfirmedForPlacement = nil
                self.modelPlaced = modelPlaced;
            }
        }
    }
    
    func removeDetectedPlanes(view: ARView) {
        for detectedPlaneInfo in detectedPlanes.values {
            if let anchorEntity = detectedPlaneInfo.visualizedAnchorEntity {
                view.scene.removeAnchor(anchorEntity)
                detectedPlaneInfo.visualizedAnchorEntity = nil
                print("plane removed  \(anchorEntity.id)")
            }
            else {
                print("no viz added for plane!")
            }
        }
    }
    
    func placeModel(view: ARView,
                    model: Model,
                    modelInfo: ModelInfo,
                    entryPointInfo: EntryPointInfo) -> Bool {
        
        guard let modelEntity = model.modelEntity else {
            print("Condo model not loaded!");
            return false;
        }
        
        let (resolvedPlanes,msg) = self.identifyPlanes(entryPointInfo: entryPointInfo)
        
        //check for success finding the planes
        guard let planeInfoArray = resolvedPlanes else {
            let errorMsg = msg != nil ? msg! : "Walls and floor could not be found"
            print(errorMsg)
            return false;
        }
        
        let transform = self.createObjectTransform(
            planeInfoArray: planeInfoArray,
            modelInfo: modelInfo,
            entryPointInfo: entryPointInfo
        )
        
        print("new transform: \(transform)")
        condoAnchorEntity = AnchorEntity(world: transform)
        
        //add this if we need to scale the model
        //we might also want axes rotation here too
        //modelEntity.setScale(simd_float3(0.01,0.01,0.01),relativeTo: condoAnchorEntity)
        
        condoAnchorEntity!.addChild(modelEntity)
        view.scene.addAnchor(condoAnchorEntity!)
        
        return true;
    }
    
    func identifyPlanes(entryPointInfo:EntryPointInfo) -> ([DetectedPlaneInfo]?,String?) {
        let cornerNormalAlignment = entryPointInfo.cornerNormalAlignment;
        
        var yPlane: DetectedPlaneInfo?
        var vPlanes =  [DetectedPlaneInfo]()
        
        for detectedPlaneInfo in detectedPlanes.values {
            if (cornerNormalAlignment[1] == true)&&(detectedPlaneInfo.type == DetectedPlaneInfo.PlaneType.HORIZONTAL_UP) {
                if(yPlane != nil) {
                    //second Y candidate - not valid scenario
                    return (nil,"Too many floor candidates!")
                }
                yPlane = detectedPlaneInfo
            }
            else if (cornerNormalAlignment[1] == false)&&(detectedPlaneInfo.type == DetectedPlaneInfo.PlaneType.HORIZONTAL_DOWN) {
                if(yPlane != nil) {
                    //second Y candidate - not valid scenario
                    return (nil,"Too many floor candidates!")
                }
                yPlane = detectedPlaneInfo
            }
            else if detectedPlaneInfo.type == DetectedPlaneInfo.PlaneType.VERTICAL {
                vPlanes.append(detectedPlaneInfo)
            }
        }
        
        //we want two vertical planes that are orthoganol
        if(vPlanes.count < 2) {
            return (nil,"Not enough wall candidates!")
        }
        
        //find the x and z plane candidates
        var xPlaneCandidate,zPlaneCandidate: DetectedPlaneInfo?
        for i in (0..<vPlanes.count-1) {
            let plane1 = vPlanes[i]
            for j in (i..<vPlanes.count) {
                let plane2 = vPlanes[j]
                print("orthogonal test: \(simd_length(simd_cross(plane1.worldNormal3,plane2.worldNormal3)))")
                if DetectedPlaneInfo.vectorsOrthogonal(plane1.worldNormal3, plane2.worldNormal3) {
                    if(xPlaneCandidate != nil) {
                        //oops - we already found a pair
                        return (nil,"Too many wall candidates")
                    }
                    
                    xPlaneCandidate = plane1
                    zPlaneCandidate = plane2
                }
            }
        }
        
        if(xPlaneCandidate == nil) {
            //no x and z candidates found
            return (nil,"No valid wall candidates found")
        }
                  
        //if we get here, we found only one valid combination
        
        //the proper planes will be right handed (once corrected for corner alignment reltive to axes)
        
        let det = simd_determinant(simd_float3x3(xPlaneCandidate!.worldNormal3,yPlane!.worldNormal3,zPlaneCandidate!.worldNormal3))
        
        var expectedDetPositive = true
        for normalAlignment in cornerNormalAlignment {
            if(!normalAlignment) {
                expectedDetPositive = !expectedDetPositive
            }
        }
        
        if (det > 0) != expectedDetPositive {
            //we guessed x and z wrong - swap them
            swap(&xPlaneCandidate,&zPlaneCandidate)
        }
        
        return ([xPlaneCandidate!,yPlane!,zPlaneCandidate!],nil)
    }
    
    func createObjectTransform(planeInfoArray: [DetectedPlaneInfo],
                               modelInfo: ModelInfo,
                               entryPointInfo:EntryPointInfo) -> simd_float4x4 {
        
        let cornerNormalAlignment = entryPointInfo.cornerNormalAlignment;
        
        //===========
        //orthogonalize the normals
        //===========
        
        //tke y to be the y unit vector -
        let yNormal = unitY;
        
        var initialX = planeInfoArray[0].worldNormal4
        if(!cornerNormalAlignment[0]) {
            initialX = getVectorNegative(initialX)
        }
        let xNormal = projectOut(inputVector: initialX, projectOut: yNormal)
            
        var initialZ = planeInfoArray[2].worldNormal4
        if(!cornerNormalAlignment[2]) {
            initialZ = getVectorNegative(initialZ)
        }
        initialZ = projectOut(inputVector: initialZ, projectOut: yNormal)
        let zNormal = projectOut(inputVector: initialZ, projectOut: xNormal)
        
        print("local y unit vector: \(yNormal)")
        print("local x unit vector: \(xNormal)")
        print("local z unit vector: \(zNormal)")
        
        //=============
        // Find the intersction of all three planes
        //=============
        
        let intersectionMatrix = simd_float4x4(
            getInPlaneColumn(detectedPlaneInfo: planeInfoArray[0]),
            getInPlaneColumn(detectedPlaneInfo: planeInfoArray[1]),
            getInPlaneColumn(detectedPlaneInfo: planeInfoArray[2]),
            zeroVector
        ).transpose
        
        print("intersectionMatrix \(intersectionMatrix)")
        
        let intersectionVector = simd_mul(intersectionMatrix.inverse,zeroVector)
        print("intersection vector \(intersectionVector)")
        
        //check the intersection projected into each local coordinate system has y=0
        print("intersection test 0: \(simd_mul(planeInfoArray[0].detectedAnchor.transform.inverse,intersectionVector))")
        print("intersection test 1: \(simd_mul(planeInfoArray[1].detectedAnchor.transform.inverse,intersectionVector))")
        print("intersection test 2: \(simd_mul(planeInfoArray[2].detectedAnchor.transform.inverse,intersectionVector))")
        
        //===============
        //create the transform for the model
        //===============
        
        let newLocalToWorld = createTransform(
            modelInfo: modelInfo,
            entryPointInfo: entryPointInfo,
            xNormal: xNormal,
            yNormal: yNormal,
            zNormal: zNormal,
            location: intersectionVector)
        
        return newLocalToWorld;
    }
    
    func getInPlaneColumn(detectedPlaneInfo: DetectedPlaneInfo) -> simd_float4 {
        return simd_mul(unitY,detectedPlaneInfo.detectedAnchor.transform.inverse)
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
    
    func getVectorNegative(_ input:simd_float4) -> simd_float4 {
        return simd_float4(-input[0],-input[1],-input[2],input[3])
    }
    
    func createTransform(
        modelInfo: ModelInfo,
        entryPointInfo: EntryPointInfo,
        xNormal: simd_float4,
        yNormal: simd_float4,
        zNormal: simd_float4,
        location: simd_float4) -> simd_float4x4 {
        
        //================
        //model parameters
        //================
        //the input model is in cm (with conversion I am using)
        //the axes have been aligned to what is used by arkit
        
        let modelOriginLocation = modelInfo.modelOriginSketchupCM
        let modelEntryPointLocation = entryPointInfo.entryPointSketchupCM
        
        //I convert the offset directions (entered as sketchup) to l directions
        let modelOffset = simd_float4(
            modelOriginLocation[0] - modelEntryPointLocation[0],
            modelOriginLocation[2] - modelEntryPointLocation[2],
            -modelOriginLocation[1] + modelEntryPointLocation[1],
            1
        )
        
        //convert from model directions to local directions
        //assume input model
        let modelToLocalLocation = simd_float4x4(
            unitX,
            unitY,
            unitZ,
            modelOffset
        )
        
        //convert local coordinates to world coordinates
        let localToWorld = simd_float4x4(
            xNormal,
            yNormal,
            zNormal,
            location
        )
            
        //chain the transformations
        return simd_mul(localToWorld,modelToLocalLocation)
    }
    
    
    
}

struct EntryPointPickerView: View {
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedEntryPoint: EntryPointInfo?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                ForEach(modelInfo.entryPoints) { entryPointInfo in
                    Button(entryPointInfo.id) {
                        print("DEBUG: Model with name : \(entryPointInfo.id)")
                        
                        self.selectedEntryPoint = entryPointInfo
                        self.isPlacementEnabled = true;
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
    @Binding var selectedEntryPoint: EntryPointInfo?
    @Binding var entryPointConfirmedForPlacement: EntryPointInfo?
    
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
                self.entryPointConfirmedForPlacement = self.selectedEntryPoint
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
        self.isPlacementEnabled = false
        self.selectedEntryPoint = nil
    }
    
}

//=============================================
// This is the Custom AR View
class CustomARView: ARView, ARSessionDelegate {
    var viewContainer: ARViewContainer?
    
    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        
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
        guard let vc = viewContainer else {
            return;
        }
        
        if(!vc.modelPlaced) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    var detectedPlane = detectedPlanes[planeAnchor.identifier]
                    if detectedPlane != nil {
                        detectedPlane!.update(updatedAnchor: planeAnchor)
                    }
                    else {
                        print("New Plane found: \(planeAnchor.identifier)")
                        detectedPlane = DetectedPlaneInfo(detectedAnchor: planeAnchor)
                        detectedPlanes[planeAnchor.identifier] = detectedPlane
                    }
                    
                    if let oldAnchorEntity = detectedPlane!.visualizedAnchorEntity {
                        self.scene.removeAnchor(oldAnchorEntity)
                        detectedPlane!.visualizedAnchorEntity = nil
                    }
                    if let newAnchorEntity = detectedPlane!.updatedAnchorEntity {
                        self.scene.addAnchor(newAnchorEntity)
                        detectedPlane!.updatedAnchorEntity = nil
                        detectedPlane!.visualizedAnchorEntity = newAnchorEntity
                    }
                
                }
            }
        }
    }
}

//func printPlanes() {
//    for planeAnchor in detectedPlanes.values {
//        printPlane(planeAnchor: planeAnchor)
//    }
//}

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

//alternate - instead of "Entity?" use ?: "(Entity & HasAnchoring)?"
func loadUnanchoredScene(fileName: String, fileExtension: String, sceneName: String)  {
        
    print("Try to load scene: \(sceneName)")
  
    //========
    guard let realityFileUrl = Bundle.main.url(
        forResource: fileName,
        withExtension: fileExtension) else {
            print("Error finding entity file: \(fileName)\(fileExtension)")
            return
        }
    
//    guard let realityFilePath = Bundle.main.path(
//        forResource: fileName,
//        ofType: fileExtension) else {
//            print("Error finding entity file: \(fileName)\(fileExtension)")
//            return
//        }
//    let realityFileUrl = URL(fileURLWithPath: realityFilePath)
    //=======
    
    let realityFileSceneURL = realityFileUrl.appendingPathComponent(sceneName,isDirectory: false)
    
    //to load without anchor, we use "load" instead of "loadAnchor"
    let loadRequest = Entity.loadAsync(contentsOf: realityFileSceneURL)
    
 //   let loadRequest = Entity.loadAsync(named: sceneName)
    let cancellable = loadRequest.sink(receiveCompletion: { loadCompletion in
        //handle error
        print("Error loading scene: \(sceneName)")
        if let c = externalLoading[sceneName] {
            c.cancel()
        }
    }, receiveValue: { entity in
        externalScenes[sceneName] = entity
        print("Success loading scene: \(entity.id) \(entity.children.count) \(sceneName)")
        if let c = externalLoading[sceneName] {
            c.cancel()
        }
    })
    externalLoading[sceneName] = cancellable
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

//old placement code
//
////dont reset session
////            if model.modelName == "fender_stratocaster" {
////                //model 0 selected - stop plane detection
////                if let customARView = uiView as? CustomARView {
////                    customARView.setupARView(enablePlaneDetection: false)
////                    print("Reconfig with no plane detection!")
////                }
////                else {
////                    print("Failed reconfig - incorrect ARView type!")
////                }
////
////            }
////            else
//            if model.modelName == "toy_drummer" {
//                //model 1 selected - print detected planes
//                //printPlanes()
//                //addPlanes(view: uiView)
//
////                if let planeAnchor = aPlane {
////                    print("Adding a plane instead of model 1")
////                    let meshResource = MeshResource.generatePlane(width: planeAnchor.extent[0], depth: planeAnchor.extent[1])
////                    let material = SimpleMaterial(color: SimpleMaterial.Color.cyan, isMetallic: true)
////                    let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
////
////                    let anchorEntity = AnchorEntity(plane: .any)
////                    anchorEntity.addChild(modelEntity.clone(recursive: true))
////                    uiView.scene.addAnchor(anchorEntity)
////                }
//
//
//                //add the existing model to the plane location
////                if let modelEntity = model.modelEntity {
////                    for planeAnchor in detectedPlanes.values {
////                        let anchorEntity = AnchorEntity(world: planeAnchor.transform)
////
////                        print("detected plane transform: \(planeAnchor.transform)")
////                        print("new entity transform \(anchorEntity.transform)")
////
////                        anchorEntity.addChild(modelEntity.clone(recursive: true))
////                        uiView.scene.addAnchor(anchorEntity)
////                    }
////                }
//
////                for planeAnchor in detectedPlanes.values {
////                    let anchorEntity = AnchorEntity(world: planeAnchor.transform)
////
////                    let meshResource = MeshResource.generatePlane(width: planeAnchor.extent[0], depth: planeAnchor.extent[2])
////                    //let meshResource = MeshResource.generatePlane(width: 0.3, depth: 0.3)
////                    //let meshResource = MeshResource.generateSphere(radius: 0.3)
////                    let material = SimpleMaterial(color: SimpleMaterial.Color.cyan, isMetallic: true)
////                    let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
////
////                    anchorEntity.addChild(modelEntity.clone(recursive: true))
////                    uiView.scene.addAnchor(anchorEntity)
////                }
//            }
//            else if model.modelName == "condo" {
//                guard let modelToPlace = condoModel else {
//                    print("Condo model does not exist!");
//                    return;
//                }
//
//                let entryPointInfo = modelInfo.entryPoints[0];
//                placeModel(
//                    view: uiView,
//                    model: modelToPlace,
//                    modelInfo: modelInfo,
//                    entryPointInfo: entryPointInfo)
//            }
//            else if model.modelName == "fender_stratocaster" {
//                guard let modelToPlace = condoModel else {
//                    print("Condo model does not exist!");
//                    return;
//                }
//
//                let entryPointInfo = modelInfo.entryPoints[1];
//                placeModel(
//                    view: uiView,
//                    model: modelToPlace,
//                    modelInfo: modelInfo,
//                    entryPointInfo: entryPointInfo)
//            }
//            else if model.modelName == "toy_biplane" {
//                guard let entity = externalScenes["ChristmasScene"] else {
//                    print("Christmas scene not loaded!");
//                    return
//                }
//
//                guard let baseAnchorEntity = condoAnchorEntity else {
//                    print("Building model not yet loaded!")
//                    return
//                }
//
//                baseAnchorEntity.addChild(entity)
//            }
//            else if model.modelName == "toy_robot_vintage" {
//                guard let entity = externalScenes["BowlingScene"] else {
//                    print("Bowling scene not loaded!");
//                    return
//                }
//
//                guard let baseAnchorEntity = condoAnchorEntity else {
//                    print("Building model not yet loaded!")
//                    return
//                }
//
//                baseAnchorEntity.addChild(entity)
//            }
//            else if model.modelName == "toy_car" {
////                guard let randomAnchor = randomScene else {
////                    print("random scene not present")
////                    return
////                }
////                uiView.scene.anchors.append(randomAnchor)
//                guard let entity = externalScenes["RandomScene"] else {
//                    print("Random scene not loaded!");
//                    return
//                }
//
//                guard let baseAnchorEntity = condoAnchorEntity else {
//                    print("Building model not yet loaded!")
//                    return
//                }
//
//                baseAnchorEntity.addChild(entity)
//            }
//            else  {
//                //just place the model if it is not one of the first two
//                if let modelEntity = model.modelEntity {
//                    let anchorEntity = AnchorEntity(plane: .any)
//                    //NOTE - before we added the clone statement, it was adding the same model multiple times
//                    //in which case it removed the old placement of the model. This fixes that by adding a clone of the model
//                    anchorEntity.addChild(modelEntity.clone(recursive: true))
//                    uiView.scene.addAnchor(anchorEntity)
//                    print("DEBUG: place model - \(model.modelName)")
//                }
//                else {
//                    print("DEBUG: Unable to place model - model entity not loaded - \(model.modelName)")
//                }
//            }
//
