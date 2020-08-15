//
//  ViewController.swift
//  HomographySample
//
//  Created by lostPenguin on 15/08/2020.
//  Copyright © 2020 Freelance. All rights reserved.
//

import UIKit
import Vision
import CoreImage


class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        let referenceImg = UIImage.init(named: "IMG_2918.jpg")!
        let misalignedImg = UIImage.init(named: "IMG_2919.jpg")!
        self.homograph(referenceImage: referenceImg, floatingImage: misalignedImg)
    }
    
    func homograph(referenceImage:UIImage, floatingImage: UIImage) {
        let referenceCIImage = CIImage.init(image: referenceImage)!
        let request = VNHomographicImageRegistrationRequest(targetedCGImage: floatingImage.cgImage!, options: [:])
        
        let handler = VNSequenceRequestHandler()
        try! handler.perform([request], on: referenceImage.cgImage!)
        
        if let results = request.results as? [VNImageHomographicAlignmentObservation] {
            let observation = results.first
            let homography = observation!.warpTransform
            print(homography)
            
            //warp the image using a warp kernel
            let warpKernel = CIWarpKernel(source:
                """
                        kernel vec2 warp(mat3 homography)
                           {
                               vec3 homogen_in = vec3(destCoord().x, destCoord().y, 1.0); // create homogeneous coord
                               vec3 homogen_out = homography * homogen_in; // transform by homography
                               return homogen_out.xy / max(homogen_out.z, 0.000001); // back to normal 2D coordinate
                           }
                        
                        """
                )!
            let (col0, col1, col2) = homography.columns
            let homographyCIVector = CIVector(values:[CGFloat(col0.x), CGFloat(col0.y), CGFloat(col0.z),
                                                      CGFloat(col1.x), CGFloat(col1.y), CGFloat(col1.z),
                                                      CGFloat(col2.x), CGFloat(col2.y), CGFloat(col2.z)], count: 9)
            let ciFloatingImage = CIImage(image: floatingImage)!
            
            let warpedImage = warpKernel.apply(extent: ciFloatingImage.extent, roiCallback:
            {
                (index, rect) in
                return CGRect.infinite
            },
                                                 image: ciFloatingImage,
                                                 arguments: [homographyCIVector])!
           
            //make the warped image a bit transparent so that we can see alignment when merged
            let warpedCIImageWithAlpha = self.imageWithAlpha(image: warpedImage, alpha: 0.6)!
            //merged it with reference image
            let warpedCIImagecomposited = warpedCIImageWithAlpha.composited(over: referenceCIImage)
            
            let resultImage = UIImage(ciImage: warpedCIImagecomposited)
            self.imageView.image = resultImage
            
        }
        
    }
    
    func imageWithAlpha(image:CIImage, alpha: CGFloat) -> CIImage? {
        let img = UIImage(ciImage: image)
        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
        img.draw(at: .zero, blendMode: .normal, alpha: alpha)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return CIImage.init(image: newImage)!
    }
    
    
}

