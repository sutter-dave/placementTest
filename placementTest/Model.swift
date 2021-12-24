//
//  Model.swift
//  ModelPickerApp
//
//  Created by Dave Sutter on 12/14/21.
//

import UIKit
import RealityKit
import Combine

class Model {
    var modelName: String
    var image: UIImage
    var modelEntity: ModelEntity?
    
    //this is from the combine library
    private var cancellable: AnyCancellable? = nil
    
    init(modelName: String) {
        self.modelName = modelName
        print("loading \(modelName)")
        self.image = UIImage(named: modelName)! //this shold exist so we will force it for now
        print("loaded \(modelName)")
        
        let fileName = modelName + ".usdz"
        self.cancellable = ModelEntity.loadModelAsync(named: fileName)
            .sink(receiveCompletion: { loadCompletion in
                //handle error case
                print("DEBUG: unable to load model entity for \(self.modelName)")
            }, receiveValue: { modelEntity in
                //Get our model entity
                self.modelEntity = modelEntity
                print("DEBUG: loaded model entity for \(self.modelName)")
            })
    }
}
