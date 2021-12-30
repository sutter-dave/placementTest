//
// Random.swift
// GENERATED CONTENT. DO NOT EDIT.
//

/*
 This is the generated code that allowed the response to events for the reality file "Random"
 I changed the enum name to RandomExample so there would not be a collision
 */


import Foundation
import RealityKit
import simd
import Combine

@available(iOS 13.0, macOS 10.15, *)
public enum RandomExample {

    public class NotifyAction {

        public let identifier: Swift.String

        public var onAction: ((RealityKit.Entity?) -> Swift.Void)?

        private weak var root: RealityKit.Entity?

        fileprivate init(identifier: Swift.String, root: RealityKit.Entity?) {
            self.identifier = identifier
            self.root = root

            Foundation.NotificationCenter.default.addObserver(self, selector: #selector(actionDidFire(notification:)), name: Foundation.NSNotification.Name(rawValue: "RealityKit.NotifyAction"), object: nil)
        }

        deinit {
            Foundation.NotificationCenter.default.removeObserver(self, name: Foundation.NSNotification.Name(rawValue: "RealityKit.NotifyAction"), object: nil)
        }

        @objc
        private func actionDidFire(notification: Foundation.Notification) {
            guard let onAction = onAction else {
                return
            }

            guard let userInfo = notification.userInfo as? [Swift.String: Any] else {
                return
            }

            guard let scene = userInfo["RealityKit.NotifyAction.Scene"] as? RealityKit.Scene,
                root?.scene == scene else {
                    return
            }

            guard let identifier = userInfo["RealityKit.NotifyAction.Identifier"] as? Swift.String,
                identifier == self.identifier else {
                    return
            }

            let entity = userInfo["RealityKit.NotifyAction.Entity"] as? RealityKit.Entity

            onAction(entity)
        }

    }

    public enum LoadRealityFileError: Error {
        case fileNotFound(String)
    }

    private static var streams = [Combine.AnyCancellable]()

    public static func loadRandomScene() throws -> RandomExample.RandomScene {
        guard let realityFileURL = Foundation.Bundle(for: RandomExample.RandomScene.self).url(forResource: "Random", withExtension: "reality") else {
            throw RandomExample.LoadRealityFileError.fileNotFound("Random.reality")
        }

        let realityFileSceneURL = realityFileURL.appendingPathComponent("RandomScene", isDirectory: false)
        let anchorEntity = try RandomExample.RandomScene.loadAnchor(contentsOf: realityFileSceneURL)
        return createRandomScene(from: anchorEntity)
    }

    public static func loadRandomSceneAsync(completion: @escaping (Swift.Result<RandomExample.RandomScene, Swift.Error>) -> Void) {
        guard let realityFileURL = Foundation.Bundle(for: RandomExample.RandomScene.self).url(forResource: "Random", withExtension: "reality") else {
            completion(.failure(RandomExample.LoadRealityFileError.fileNotFound("Random.reality")))
            return
        }

        var cancellable: Combine.AnyCancellable?
        let realityFileSceneURL = realityFileURL.appendingPathComponent("RandomScene", isDirectory: false)
        let loadRequest = RandomExample.RandomScene.loadAnchorAsync(contentsOf: realityFileSceneURL)
        cancellable = loadRequest.sink(receiveCompletion: { loadCompletion in
            if case let .failure(error) = loadCompletion {
                completion(.failure(error))
            }
            streams.removeAll { $0 === cancellable }
        }, receiveValue: { entity in
            completion(.success(RandomExample.createRandomScene(from: entity)))
        })
        cancellable?.store(in: &streams)
    }

    private static func createRandomScene(from anchorEntity: RealityKit.AnchorEntity) -> RandomExample.RandomScene {
        let randomScene = RandomExample.RandomScene()
        randomScene.anchoring = anchorEntity.anchoring
        randomScene.addChild(anchorEntity)
        return randomScene
    }

    public class RandomScene: RealityKit.Entity, RealityKit.HasAnchoring {

        public var cylinder: RealityKit.Entity? {
            return self.findEntity(named: "cylinder")
        }



        public private(set) lazy var actions = RandomExample.RandomScene.Actions(root: self)

        public class Actions {

            fileprivate init(root: RealityKit.Entity) {
                self.root = root
            }

            private weak var root: RealityKit.Entity?

            public private(set) lazy var openLink = RandomExample.NotifyAction(identifier: "openLink", root: root)

            public private(set) lazy var allActions = [ openLink ]

        }

    }

}
