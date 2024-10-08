//
//  ModuleBViewController.swift
//  Lab2_MobileApps
//
//  Created by Keaton Harvey on 10/8/24.
//

import UIKit

class ModuleBViewController: UIViewController {
    
    struct AudioConstants{
            static let AUDIO_BUFFER_SIZE = 1024*4
        }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        audio.play()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            
            // Stop audio input when leaving view
        audio.pause()
        }
    
}//end of class
