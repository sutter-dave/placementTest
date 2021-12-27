//
//  EntryPointInfo.swift
//  placementTest
//
//  Created by Dave Sutter on 12/26/21.
//

import ARKit

struct EntryPointInfo {
    //coordinates of the entry point (the coordinates of the corner I am using)
    let entryPointSketchupCM: simd_float3
    
    //flagas indicating if corner plane normals match the axis in sign (plane normals are towrds phone)
    let cornerNormalAlignment: [Bool];
}
