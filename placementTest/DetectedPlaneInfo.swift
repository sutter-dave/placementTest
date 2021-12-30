//
//  DetectedPlaneInfo.swift
//  placementTest
//
//  Created by Dave Sutter on 12/29/21.
//

import ARKit
import RealityKit

class DetectedPlaneInfo {
    var detectedAnchor:ARPlaneAnchor
    var visualizedAnchorEntity:AnchorEntity?
    var updatedAnchorEntity:AnchorEntity?
    var worldNormal3: simd_float3
    var worldNormal4: simd_float4
    var type = PlaneType.OTHER
    
    let UNITY4 = simd_float4(0,1,0,0)
    let UNITY3 = simd_float3(0,1,0)
    
    static let PARALLEL_LIMIT: Float = 0.98
    static let ORTHOGONAL_LIMIT: Float = 0.96
    
    public enum PlaneType {
        case HORIZONTAL_UP
        case HORIZONTAL_DOWN
        case VERTICAL
        case OTHER
    }
    
    init(detectedAnchor: ARPlaneAnchor) {
        self.detectedAnchor = detectedAnchor
        worldNormal4 = simd_mul(detectedAnchor.transform,UNITY4)
        worldNormal3 = simd_make_float3(worldNormal4)
        self.populate()
        
        print("\(detectedAnchor.identifier): plane found: type = \(type)")
    }
    
    func update(updatedAnchor: ARPlaneAnchor) {
        if self.detectedAnchor != updatedAnchor {
            self.detectedAnchor = updatedAnchor
        }
        worldNormal4 = simd_mul(detectedAnchor.transform,UNITY4)
        worldNormal3 = simd_make_float3(worldNormal4)
        
        let oldType = type;
        
        self.populate()
        
        if(oldType != type) {
            print("\(updatedAnchor.identifier): plane type change: type = \(type)")
        }
    }
    
    private func populate() {
        //get the type of plane
        self.loadType()
        
        //create a visualization of the anchor
        let meshResource = createMeshFromPlaneVertices(vertices: detectedAnchor.geometry.vertices)
        let material = PhysicallyBasedMaterial()
        let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
        
        let anchorEntity = AnchorEntity(world: detectedAnchor.transform)
        
        //print("detected plane transform: \(anchorEntity.transform)")
        //print("new entity transform \(anchorEntity.transform)")
        
        anchorEntity.addChild(modelEntity)
        
        self.updatedAnchorEntity = anchorEntity
    }

    private func loadType() {
        if simd_dot(worldNormal3,UNITY3) > DetectedPlaneInfo.PARALLEL_LIMIT {
            self.type = PlaneType.HORIZONTAL_UP
        }
        else if simd_dot(worldNormal3,UNITY3) < -DetectedPlaneInfo.PARALLEL_LIMIT {
            self.type = PlaneType.HORIZONTAL_DOWN
        }
        else if DetectedPlaneInfo.vectorsOrthogonal(worldNormal3,UNITY3) {
            self.type = PlaneType.VERTICAL
        }
        else {
            self.type = PlaneType.OTHER
            print("other found with orthogonal: \(simd_length(simd_cross(worldNormal3,UNITY3)))")
        }
    }
    
    public static func vectorsOrthogonal(_ v1: simd_float3, _ v2: simd_float3) -> Bool {
        return simd_length(simd_cross(v1,v2)) > DetectedPlaneInfo.ORTHOGONAL_LIMIT
    }
    
}
