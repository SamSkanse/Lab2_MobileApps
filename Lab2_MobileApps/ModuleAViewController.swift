//
//  ViewController.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//

/*TODO!!! figure out how to call the function getFundamentalPeaksFromBuffer in order to get the peaks to
 to output to labels
 */


import UIKit
import Metal





class ModuleAViewController: UIViewController {
    
    
    @IBOutlet weak var userView: UIView!
    @IBOutlet weak var SecondHighest: UILabel!
    @IBOutlet weak var Highest: UILabel!
    
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 8192
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display
            // note that we need to normalize the scale of this graph
            // because the fft is returned in dB which has very large negative values and some large positive values
            
            
            graph.addGraph(withName: "fft",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            
            
            
            graph.makeGrids() // add grids to graph
        }
        
        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withFps: 20) // preferred number of FFT calculations per second
        
        audio.play()
                   
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
        
    }
    
    // periodically, update the graph with refreshed FFT Data
    func updateGraph(){
        
        if let graph = self.graph{
            graph.updateGraph(
                data: self.audio.fftData,
                forKey: "fft"
            )
            
                updateHighestFrequencyLabel()
            }
           
        
    }
    
  
    
    func updateHighestFrequencyLabel() {
            if let maxValue = self.audio.fftData.max(), maxValue < 0 {
                self.Highest.text = "Noise"
            } else if let maxValue = self.audio.fftData.max(),
                      let maxIndex = self.audio.fftData.firstIndex(of: maxValue) {
                let frequencyMaxIndex:Int = maxIndex * 48000 / 8192
                self.Highest.text = String(frequencyMaxIndex)
            }
        }
    
        

}
