//
//  ViewController.swift
//  demoarkit
//
//  Created by COUDSI Julien on 06/10/2017.
//  Copyright © 2017 TWE. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var stateLabel: UILabel!
    private var dictPlanes = [ARPlaneAnchor: Plane]()
    private var virtualCup:SCNReferenceNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sceneView.delegate = self
        self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        
        self.sceneView.autoenablesDefaultLighting = false
        self.sceneView.automaticallyUpdatesLighting = false
        if let environmentMap = UIImage(named: "Models.scnassets/sharedImages/environment.jpg") {
            self.sceneView.scene.lightingEnvironment.contents = environmentMap
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gesture:)))
        self.view.addGestureRecognizer(tapGesture)
        
        self.virtualCup = self.getVirtualCupNode()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true
        
        self.sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.sceneView.session.pause()
    }
    
    //MARK: - Gestures
    
    @objc func handleTap(gesture:UITapGestureRecognizer) {
        
        let viewPoint = gesture.location(in: self.sceneView)
        let realWorldResults = self.sceneView.hitTest(viewPoint, types: [.existingPlaneUsingExtent])
        
        if let realWorldClosestResult = realWorldResults.first {
            let anchor = ARAnchor(transform: realWorldClosestResult.worldTransform)
            self.sceneView.session.add(anchor: anchor)
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        if let lightEstimate = self.sceneView.session.currentFrame?.lightEstimate {
            self.sceneView.scene.lightingEnvironment.intensity = lightEstimate.ambientIntensity / 1000
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
            let plane = Plane(anchor: planeAnchor)
            node.addChildNode(plane)
            self.dictPlanes[planeAnchor] = plane
        } else if let virtualCup = self.virtualCup?.clone() {
            
            self.loadObject(virtualCup, loadedHandler: { objectNode in
                DispatchQueue.main.async {
                    node.addChildNode(objectNode)
                }
            })
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
            let plane = self.dictPlanes[planeAnchor]
            plane?.updateWith(planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
            self.dictPlanes.removeValue(forKey: planeAnchor)
        }
    }
    
    // MARK: - ARSession events
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        
        switch camera.trackingState {
        case ARCamera.TrackingState.notAvailable:
            self.showState("TRACKING UNAVAILABLE")
            break
        case ARCamera.TrackingState.limited(.excessiveMotion):
            self.showState("TRACKING LIMITED - Excessive motion")
            break
        case ARCamera.TrackingState.limited(.insufficientFeatures):
            self.showState("TRACKING LIMITED - Low detail")
            break
        case ARCamera.TrackingState.limited(.initializing):
            self.showState("Initializing")
            break
        case ARCamera.TrackingState.normal:
            self.showState("TRACKING NORMAL")
            break
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("error : \(error)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("sessionWasInterrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("sessionInterruptionEnded")
    }
    
    // MARK: - Helpers

    private func getVirtualCupNode() -> SCNReferenceNode? {
        let modelsURL = Bundle.main.url(forResource: "Models.scnassets/cup/cup", withExtension: "scn")!
        return SCNReferenceNode(url: modelsURL)
    }
    
    private func loadObject(_ object:SCNReferenceNode, loadedHandler: @escaping (SCNReferenceNode) -> Void) {
    
        DispatchQueue.global(qos: .userInitiated).async {
            object.load()
            loadedHandler(object)
        }
    }
    
    private func showState(_ message:String) {
        DispatchQueue.main.async {
            self.stateLabel.text = message
        }
    }
}
