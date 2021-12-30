//
//  ModelInfo.swift
//  placementTest
//
//  Created by Dave Sutter on 12/26/21.
//

import ARKit

struct ModelInfo {
    let name: String
    //the cm coordinates of the "origin" of the model
    //with my conversion to usdz, this appears in the center of the model
    //here I express them in directions from the original sketchup model, but with cm coordinates
    let modelOriginSketchupCM: simd_float3
    let entryPoints: [EntryPointInfo]
}
