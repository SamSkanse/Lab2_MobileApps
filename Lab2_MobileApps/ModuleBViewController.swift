//
//  ModuleBViewController.swift
//  Lab2_MobileApps
//
//  Created by Keaton Harvey on 10/8/24.
//

import UIKit

class ModuleBViewController: UIViewController {
    
    @IBOutlet weak var userView: UIView!
    struct AudioConstants{
            static let AUDIO_BUFFER_SIZE = 1024*4
        }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
            return MetalGraph(userView: self.userView)
        }()
    var timer:Timer? = nil
    
    var frequency:Float = 300 {
            didSet{
                audio.sineFrequency = frequency
                labelF.text = "Frequency: \(frequency)"
            }
        }
    @IBOutlet weak var labelF: UILabel!
    @IBAction func sliderF(_ sender: UISlider) {
            frequency = sender.value
        }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        frequency = 18500
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let graph = self.graph{
                    graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
                    
                    // add in graphs for display
                    // note that we need to normalize the scale of this graph
                    // because the fft is returned in dB which has very large negative values and some large positive values
                    
                    graph.addGraph(withName: "fftZoomed",
                                    shouldNormalizeForFFT: true,
                                    numPointsInGraph: 300) // 300 points to display
                    
                    graph.makeGrids() // add grids to graph
                }
        audio.startMicrophoneProcessing(withFps: 20)
        audio.play()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
    }//end of viewWillAppear
    
    override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
        timer?.invalidate()
        graph?.teardown()
        graph = nil
        audio.pause()
        super.viewDidDisappear(animated)
        }
    
    func updateGraph(){
        
        if let graph = self.graph{
            // Show the zoomed FFT
            // we can start at about 150Hz and show the next 300 points
            // actual Hz = f_0 * N/F_s
            let minfreq = frequency
            let startIdx:Int = (Int(minfreq)-50) * AudioConstants.AUDIO_BUFFER_SIZE/audio.samplingRate
            let subArray:[Float] = Array(self.audio.fftData[startIdx...startIdx+300])
            graph.updateGraph(
                data: subArray,
                forKey: "fftZoomed"
            )
            
            
        }
    }
    
    
}//end of class
