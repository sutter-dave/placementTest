//
//  PlaneInfo.swift
//  placementTest
//
//  Created by Dave Sutter on 12/23/21.
//

import ARKit

struct PlaneInfo {
    var localToWorld:simd_float4x4
    var worldToLocal:simd_float4x4
    var worldNormal:simd_float4 //this is the normal to the plane
    var yProjection:simd_float4 //this is the row of the world to local transform for the Y coordinate
}
