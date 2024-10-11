//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson.
//  Modified to fix Doppler shift detection.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    lazy var samplingRate:Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    
    var sineFrequency:Float = 440.0
    private var frequencyDeltaThreshold: Float = 15.0
    private var baselineFrequency: Float = 0.0
    private var previousFrequency: Float = 0.0
    private var frequencyBuffer: [Float] = []
    private var baselineSet: Bool = false
    
    enum Gesture {
            case toward
            case away
            case none
        }
    
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    var pulsing:Bool = false
    private var pulseValue:Int = 0
    
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessingA(withFps:Double){
        // setup the microphone to copy to circualr buffer
                if let manager = self.audioManager{
                    manager.inputBlock = self.handleMicrophone
                    
                    // repeat this fps times per second using the timer class
                    //   every time this is called, we update the arrays "timeData" and "fftData"
                    Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                        self.runEveryInterval()
                    }
                }
    }
    
    func startMicrophoneProcessingB(withFps: Double) {
        // setup the microphone to copy to circular buffer
        if let manager = self.audioManager {
            manager.inputBlock = self.handleMicrophone
            manager.outputBlock = self.handleSpeakerQueryWithSinusoids
            
            // repeat this fps times per second using the timer class
            Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
            
            Timer.scheduledTimer(withTimeInterval: 1.0 / 5.0, repeats: true) { _ in
                self.pulseValue += 1
                if self.pulseValue > 5 {
                    self.pulseValue = 0
                }
            }
        }
    }
    
    func detectGesture() -> Gesture {
        guard baselineSet else { return .none }
        
        // Get current dominant frequency from FFT
        let currentFrequency = estimateDominantFrequency()
        
        // Calculate the frequency shift relative to the baseline
        let delta = currentFrequency - baselineFrequency
        
        // Detect toward or away gestures based on the threshold
        if delta > frequencyDeltaThreshold {
            return .toward
        } else if delta < -frequencyDeltaThreshold {
            return .away
        } else {
            return .none
        }
    }
    
    private func estimateDominantFrequency() -> Float {
        let minFrequency = 17000 // 17 kHz minimum
        let maxFrequency = 20000 // 20 kHz maximum
        
        let minIndex = Int(minFrequency * BUFFER_SIZE / samplingRate)
        let maxIndex = Int(maxFrequency * BUFFER_SIZE / samplingRate)
        
        var dominantIndex = minIndex // Renamed from maxIndex to avoid conflict
        var maxValue = fftData[minIndex]
        
        for index in minIndex...maxIndex where fftData[index] > maxValue {
            maxValue = fftData[index]
            dominantIndex = index
        }
        
        return Float(dominantIndex) * Float(samplingRate) / Float(BUFFER_SIZE)
    }
    
    func updateBaselineFrequency(_ frequency: Float) {
        baselineFrequency = frequency
        previousFrequency = frequency // Reset previous to prevent false detections
        frequencyBuffer.removeAll() // Clear any past readings in the buffer
        baselineSet = true
    }
    
    private func movingAverageFrequency(currentFrequency: Float) -> Float {
        // Add new frequency to buffer, limit buffer size to 10
        frequencyBuffer.append(currentFrequency)
        if frequencyBuffer.count > 10 {
            frequencyBuffer.removeFirst()
        }
        // Calculate the average of the buffer
        return frequencyBuffer.reduce(0, +) / Float(frequencyBuffer.count)
    }
    
    
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
    }
    
    func stop() {
        if let manager = self.audioManager {
            manager.pause()
            manager.inputBlock = nil
            manager.outputBlock = nil
        }
        
        if let buffer = self.inputBuffer {
            buffer.clear() // just makes zeros
        }
        inputBuffer = nil
        fftHelper = nil
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData, // copied into this array
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData) // fft result is copied into fftData array
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
        }
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    
  /*  private func handleSpeakerQueryWithSinusoids(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
            if let arrayData = data, let manager = self.audioManager{
                
                var addFreq:Float = 0
                var mult:Float = 1.0
                if pulsing && pulseValue==1{
                    addFreq = 1000.0
                }else if pulsing && pulseValue > 1{
                    mult = 0.0
                }
                
                
                
                phaseIncrement = Float(2*Double.pi*Double(sineFrequency+addFreq)/manager.samplingRate)
                
                
                var i = 0
                let chan = Int(numChannels)
                let frame = Int(numFrames)
                if chan==1{
                    while i<frame{
                        arrayData[i] += (0.9*sin(phase))*mult
                        phase += phaseIncrement
                        if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                        i+=1
                    }
                }else if chan==2{
                    let len = frame*chan
                    while i<len{
                        arrayData[i] += (0.9*sin(phase))*mult
                        arrayData[i+1] = arrayData[i]
                        phase += phaseIncrement
                        if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                        i+=2
                    }
                }
                
            }
        }
    
    
} */


private func handleSpeakerQueryWithSinusoids(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        if let arrayData = data, let manager = self.audioManager {
            
            var addFreq: Float = 0
            var mult: Float = 1.0
            if pulsing && pulseValue == 1 {
                addFreq = 1000.0
            } else if pulsing && pulseValue > 1 {
                mult = 0.0
            }
            
           
            
            // Generate sine wave without audio file
            phaseIncrement = Float(2 * Double.pi * Double(sineFrequency + addFreq) / manager.samplingRate)
            
            var volume:Float = mult*0.15 // zero out song also, if needed
            vDSP_vsmul(arrayData, 1, &(volume), arrayData, 1, vDSP_Length(numFrames*numChannels))
            
            
            var i = 0
            let chan = Int(numChannels)
            let frame = Int(numFrames)
            if chan == 1 {
                while i < frame {
                    arrayData[i] += (0.9 * sin(phase)) * mult
                    phase += phaseIncrement
                    if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                    i += 1
                }
            } else if chan == 2 {
                let len = frame * chan
                while i < len {
                    arrayData[i] += (0.9 * sin(phase)) * mult
                    arrayData[i + 1] = arrayData[i]
                    phase += phaseIncrement
                    if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                    i += 2
                }
            }
        }
    }
}



/* attempted change for doppler shifts but does not work
 import Foundation
 import Accelerate

 class AudioModel {
     
     // MARK: Properties
     private var BUFFER_SIZE: Int
     // these properties are for interfacing with the API
     var timeData: [Float]
     var fftData: [Float]
     lazy var samplingRate: Int = {
         return Int(self.audioManager!.samplingRate)
     }()
     
     var sineFrequency: Float = 440.0
     private var frequencyDeltaThreshold: Float = 50.0 // Adjusted threshold
     private var baselineFrequency: Float = 0.0
     private var frequencyBuffer: [Float] = []
     private var baselineSet: Bool = false
     
     enum Gesture {
         case toward
         case away
         case none
     }
     
     private var phase: Float = 0.0
     private var phaseIncrement: Float = 0.0
     private var sineWaveRepeatMax: Float = Float(2 * Double.pi)
     var pulsing: Bool = false
     private var pulseValue: Int = 0
     
     // MARK: Public Methods
     init(buffer_size: Int) {
         BUFFER_SIZE = buffer_size
         // allocate arrays
         timeData = Array(repeating: 0.0, count: BUFFER_SIZE)
         fftData = Array(repeating: 0.0, count: BUFFER_SIZE / 2)
     }
     
     func startMicrophoneProcessingA(withFps: Double) {
         // setup the microphone to copy to circular buffer
         if let manager = self.audioManager {
             manager.inputBlock = self.handleMicrophone
             
             // update data arrays at specified FPS
             Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                 self.runEveryInterval()
             }
         }
     }
     
     func startMicrophoneProcessingB(withFps: Double) {
         // setup the microphone to copy to circular buffer
         if let manager = self.audioManager {
             manager.inputBlock = self.handleMicrophone
             manager.outputBlock = self.handleSpeakerQueryWithSinusoids
             
             // update data arrays at specified FPS
             Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                 self.runEveryInterval()
             }
             
             Timer.scheduledTimer(withTimeInterval: 1.0 / 5.0, repeats: true) { _ in
                 self.pulseValue += 1
                 if self.pulseValue > 5 {
                     self.pulseValue = 0
                 }
             }
         }
     }
     
     func detectGesture() -> Gesture {
         guard baselineSet else { return .none }
         
         // Get current dominant frequency from FFT
         let currentFrequency = estimateDominantFrequency()
         
         // Apply moving average to smooth out frequency fluctuations
         let smoothedFrequency = movingAverageFrequency(currentFrequency: currentFrequency)
         
         // Calculate the frequency shift relative to the baseline
         let delta = smoothedFrequency - baselineFrequency
         
         // Detect toward or away gestures based on the threshold
         if delta > frequencyDeltaThreshold {
             return .toward
         } else if delta < -frequencyDeltaThreshold {
             return .away
         } else {
             return .none
         }
     }
     
     private func estimateDominantFrequency() -> Float {
         // Define a frequency window around sineFrequency
         let frequencyWindow: Float = 1000.0 // 1 kHz window
         let minFrequency = sineFrequency - frequencyWindow
         let maxFrequency = sineFrequency + frequencyWindow
         
         // Ensure frequencies are within valid ranges
         let minFreq = max(0, minFrequency)
         let maxFreq = min(Float(samplingRate) / 2, maxFrequency)
         
         let minIndex = Int(minFreq * Float(BUFFER_SIZE) / Float(samplingRate))
         let maxIndex = Int(maxFreq * Float(BUFFER_SIZE) / Float(samplingRate))
         
         // Ensure indices are within fftData bounds
         let minIdx = max(0, minIndex)
         let maxIdx = min(maxIndex, fftData.count - 1)
         
         var dominantIndex = minIdx
         var maxValue = fftData[minIdx]
         
         for index in minIdx...maxIdx where fftData[index] > maxValue {
             maxValue = fftData[index]
             dominantIndex = index
         }
         
         return Float(dominantIndex) * Float(samplingRate) / Float(BUFFER_SIZE)
     }
     
     func updateBaselineFrequency(_ frequency: Float) {
         // Set sineFrequency and update baseline to the detected dominant frequency
         sineFrequency = frequency
         baselineFrequency = estimateDominantFrequency()
         frequencyBuffer.removeAll()
         baselineSet = true
     }
     
     private func movingAverageFrequency(currentFrequency: Float) -> Float {
         // Add new frequency to buffer, limit buffer size to 5
         frequencyBuffer.append(currentFrequency)
         if frequencyBuffer.count > 5 {
             frequencyBuffer.removeFirst()
         }
         // Calculate the average of the buffer
         return frequencyBuffer.reduce(0, +) / Float(frequencyBuffer.count)
     }
     
     func play() {
         if let manager = self.audioManager {
             manager.play()
         }
     }
     
     func stop() {
         if let manager = self.audioManager {
             manager.pause()
             manager.inputBlock = nil
             manager.outputBlock = nil
         }
         
         if let buffer = self.inputBuffer {
             buffer.clear() // just makes zeros
         }
         inputBuffer = nil
         fftHelper = nil
     }
     
     //==========================================
     // MARK: Private Properties
     private lazy var audioManager: Novocaine? = {
         return Novocaine.audioManager()
     }()
     
     private lazy var fftHelper: FFTHelper? = {
         return FFTHelper(fftSize: Int32(BUFFER_SIZE))
     }()
     
     private lazy var inputBuffer: CircularBuffer? = {
         return CircularBuffer(numChannels: Int64(self.audioManager!.numInputChannels),
                               andBufferSize: Int64(BUFFER_SIZE))
     }()
     
     //==========================================
     // MARK: Model Callback Methods
     private func runEveryInterval() {
         if inputBuffer != nil {
             // copy time data to swift array
             self.inputBuffer!.fetchFreshData(&timeData,
                                              withNumSamples: Int64(BUFFER_SIZE))
             
             // now take FFT
             fftHelper!.performForwardFFT(withData: &timeData,
                                          andCopydBMagnitudeToBuffer: &fftData)
         }
     }
     
     //==========================================
     // MARK: Audiocard Callbacks
     private func handleMicrophone(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
         // copy samples from the microphone into circular buffer
         self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
     }
     
     private func handleSpeakerQueryWithSinusoids(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
         if let arrayData = data, let manager = self.audioManager {
             
             var addFreq: Float = 0
             var mult: Float = 1.0
             if pulsing && pulseValue == 1 {
                 addFreq = 1000.0
             } else if pulsing && pulseValue > 1 {
                 mult = 0.0
             }
             
             // Generate sine wave
             phaseIncrement = Float(2 * Double.pi * Double(sineFrequency + addFreq) / manager.samplingRate)
             
             var i = 0
             let chan = Int(numChannels)
             let frame = Int(numFrames)
             if chan == 1 {
                 while i < frame {
                     arrayData[i] += (0.9 * sin(phase)) * mult
                     phase += phaseIncrement
                     if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                     i += 1
                 }
             } else if chan == 2 {
                 let len = frame * chan
                 while i < len {
                     arrayData[i] += (0.9 * sin(phase)) * mult
                     arrayData[i + 1] = arrayData[i]
                     phase += phaseIncrement
                     if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                     i += 2
                 }
             }
         }
     }
 }
 */





/* this works with the pre-doppler changes
 import Foundation
 import Accelerate

 class AudioModel {
     
     // MARK: Properties
     private var BUFFER_SIZE:Int
     // thse properties are for interfaceing with the API
     // the user can access these arrays at any time and plot them if they like
     var timeData:[Float]
     var fftData:[Float]
     lazy var samplingRate:Int = {
         return Int(self.audioManager!.samplingRate)
     }()
     
     var sineFrequency:Float = 440.0
     private var frequencyDeltaThreshold: Float = 15.0
     private var baselineFrequency: Float = 0.0
     private var previousFrequency: Float = 0.0
     private var frequencyBuffer: [Float] = []
     private var baselineSet: Bool = false
     
     enum Gesture {
             case toward
             case away
             case none
         }
     
     private var phase:Float = 0.0
     private var phaseIncrement:Float = 0.0
     private var sineWaveRepeatMax:Float = Float(2*Double.pi)
     var pulsing:Bool = false
     private var pulseValue:Int = 0
     
     
     // MARK: Public Methods
     init(buffer_size:Int) {
         BUFFER_SIZE = buffer_size
         // anything not lazily instatntiated should be allocated here
         timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
         fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
     }
     
     // public function for starting processing of microphone data
     func startMicrophoneProcessingA(withFps:Double){
         // setup the microphone to copy to circualr buffer
                 if let manager = self.audioManager{
                     manager.inputBlock = self.handleMicrophone
                     
                     // repeat this fps times per second using the timer class
                     //   every time this is called, we update the arrays "timeData" and "fftData"
                     Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                         self.runEveryInterval()
                     }
                 }
     }
     
     func startMicrophoneProcessingB(withFps: Double) {
         // setup the microphone to copy to circular buffer
         if let manager = self.audioManager {
             manager.inputBlock = self.handleMicrophone
             manager.outputBlock = self.handleSpeakerQueryWithSinusoids
             
             // repeat this fps times per second using the timer class
             Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                 self.runEveryInterval()
             }
             
             Timer.scheduledTimer(withTimeInterval: 1.0 / 5.0, repeats: true) { _ in
                 self.pulseValue += 1
                 if self.pulseValue > 5 {
                     self.pulseValue = 0
                 }
             }
         }
     }
     
     func detectGesture() -> Gesture {
         guard baselineSet else { return .none }
         
         // Get current dominant frequency from FFT
         let currentFrequency = estimateDominantFrequency()
         
         // Calculate the frequency shift relative to the baseline
         let delta = currentFrequency - baselineFrequency
         
         // Detect toward or away gestures based on the threshold
         if delta > frequencyDeltaThreshold {
             return .toward
         } else if delta < -frequencyDeltaThreshold {
             return .away
         } else {
             return .none
         }
     }
     
     private func estimateDominantFrequency() -> Float {
         let minFrequency = 17000 // 17 kHz minimum
         let maxFrequency = 20000 // 20 kHz maximum
         
         let minIndex = Int(minFrequency * BUFFER_SIZE / samplingRate)
         let maxIndex = Int(maxFrequency * BUFFER_SIZE / samplingRate)
         
         var dominantIndex = minIndex // Renamed from maxIndex to avoid conflict
         var maxValue = fftData[minIndex]
         
         for index in minIndex...maxIndex where fftData[index] > maxValue {
             maxValue = fftData[index]
             dominantIndex = index
         }
         
         return Float(dominantIndex) * Float(samplingRate) / Float(BUFFER_SIZE)
     }
     
     func updateBaselineFrequency(_ frequency: Float) {
         baselineFrequency = frequency
         previousFrequency = frequency // Reset previous to prevent false detections
         frequencyBuffer.removeAll() // Clear any past readings in the buffer
         baselineSet = true
     }
     
     private func movingAverageFrequency(currentFrequency: Float) -> Float {
         // Add new frequency to buffer, limit buffer size to 10
         frequencyBuffer.append(currentFrequency)
         if frequencyBuffer.count > 10 {
             frequencyBuffer.removeFirst()
         }
         // Calculate the average of the buffer
         return frequencyBuffer.reduce(0, +) / Float(frequencyBuffer.count)
     }
     
     
     
     // You must call this when you want the audio to start being handled by our model
     func play(){
         if let manager = self.audioManager{
             manager.play()
         }
     }
     
     func stop() {
         if let manager = self.audioManager {
             manager.pause()
             manager.inputBlock = nil
             manager.outputBlock = nil
         }
         
         if let buffer = self.inputBuffer {
             buffer.clear() // just makes zeros
         }
         inputBuffer = nil
         fftHelper = nil
     }
     
     
     //==========================================
     // MARK: Private Properties
     private lazy var audioManager:Novocaine? = {
         return Novocaine.audioManager()
     }()
     
     private lazy var fftHelper:FFTHelper? = {
         return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
     }()
     
     
     private lazy var inputBuffer:CircularBuffer? = {
         return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                    andBufferSize: Int64(BUFFER_SIZE))
     }()
     
     
     //==========================================
     // MARK: Private Methods
     // NONE for this model
     
     //==========================================
     // MARK: Model Callback Methods
     private func runEveryInterval(){
         if inputBuffer != nil {
             // copy time data to swift array
             self.inputBuffer!.fetchFreshData(&timeData, // copied into this array
                                              withNumSamples: Int64(BUFFER_SIZE))
             
             // now take FFT
             fftHelper!.performForwardFFT(withData: &timeData,
                                          andCopydBMagnitudeToBuffer: &fftData) // fft result is copied into fftData array
             
             // at this point, we have saved the data to the arrays:
             //   timeData: the raw audio samples
             //   fftData:  the FFT of those same samples
             // the user can now use these variables however they like
             
         }
     }
     
     //==========================================
     // MARK: Audiocard Callbacks
     // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
     // and in swift this translates to:
     private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
         // copy samples from the microphone into circular buffer
         self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
     }
     
     
   /*  private func handleSpeakerQueryWithSinusoids(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
             if let arrayData = data, let manager = self.audioManager{
                 
                 var addFreq:Float = 0
                 var mult:Float = 1.0
                 if pulsing && pulseValue==1{
                     addFreq = 1000.0
                 }else if pulsing && pulseValue > 1{
                     mult = 0.0
                 }
                 
                 
                 
                 phaseIncrement = Float(2*Double.pi*Double(sineFrequency+addFreq)/manager.samplingRate)
                 
                 
                 var i = 0
                 let chan = Int(numChannels)
                 let frame = Int(numFrames)
                 if chan==1{
                     while i<frame{
                         arrayData[i] += (0.9*sin(phase))*mult
                         phase += phaseIncrement
                         if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                         i+=1
                     }
                 }else if chan==2{
                     let len = frame*chan
                     while i<len{
                         arrayData[i] += (0.9*sin(phase))*mult
                         arrayData[i+1] = arrayData[i]
                         phase += phaseIncrement
                         if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                         i+=2
                     }
                 }
                 
             }
         }
     
     
 } */


 private func handleSpeakerQueryWithSinusoids(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
         if let arrayData = data, let manager = self.audioManager {
             
             var addFreq: Float = 0
             var mult: Float = 1.0
             if pulsing && pulseValue == 1 {
                 addFreq = 1000.0
             } else if pulsing && pulseValue > 1 {
                 mult = 0.0
             }
             
             var volume:Float = mult*0.15 // zero out song also, if needed
             vDSP_vsmul(arrayData, 1, &(volume), arrayData, 1, vDSP_Length(numFrames*numChannels))
             
             // Generate sine wave without audio file
             phaseIncrement = Float(2 * Double.pi * Double(sineFrequency + addFreq) / manager.samplingRate)
             
             var i = 0
             let chan = Int(numChannels)
             let frame = Int(numFrames)
             if chan == 1 {
                 while i < frame {
                     arrayData[i] += (0.9 * sin(phase)) * mult
                     phase += phaseIncrement
                     if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                     i += 1
                 }
             } else if chan == 2 {
                 let len = frame * chan
                 while i < len {
                     arrayData[i] += (0.9 * sin(phase)) * mult
                     arrayData[i + 1] = arrayData[i]
                     phase += phaseIncrement
                     if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                     i += 2
                 }
             }
         }
     }
 }
 
 */




/*
 //
 //  AudioModel.swift
 //  AudioLabSwift
 //
 //  Created by Eric Larson
 //  Copyright © 2020 Eric Larson. All rights reserved.
 //


 import Foundation
 import Accelerate

 class AudioModel {
     
     // MARK: Properties
     private var BUFFER_SIZE:Int
     // thse properties are for interfaceing with the API
     // the user can access these arrays at any time and plot them if they like
     var timeData:[Float]
     var fftData:[Float]
     lazy var samplingRate:Int = {
         return Int(self.audioManager!.samplingRate)
     }()
     
     var sineFrequency:Float = 300.0
     private var frequencyDeltaThreshold: Float = 15.0
     private var baselineFrequency: Float = 0.0
     private var previousFrequency: Float = 0.0
     private var frequencyBuffer: [Float] = []
     private var baselineSet: Bool = false
     
     enum Gesture {
             case toward
             case away
             case none
         }
     
     private var phase:Float = 0.0
     private var phaseIncrement:Float = 0.0
     private var sineWaveRepeatMax:Float = Float(2*Double.pi)
     var pulsing:Bool = false
     private var pulseValue:Int = 0
     
     
     // MARK: Public Methods
     init(buffer_size:Int) {
         BUFFER_SIZE = buffer_size
         // anything not lazily instatntiated should be allocated here
         timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
         fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
     }
     
     // public function for starting processing of microphone data
     func startMicrophoneProcessingA(withFps:Double){
         // setup the microphone to copy to circualr buffer
                 if let manager = self.audioManager{
                     manager.inputBlock = self.handleMicrophone
                     
                     // repeat this fps times per second using the timer class
                     //   every time this is called, we update the arrays "timeData" and "fftData"
                     Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                         self.runEveryInterval()
                     }
                 }
     }
     
     func startMicrophoneProcessingB(withFps:Double){
         // setup the microphone to copy to circualr buffer
         if let manager = self.audioManager,
             let fileReader = self.fileReader{
             manager.inputBlock = self.handleMicrophone
             manager.outputBlock = self.handleSpeakerQueryWithSinusoids
             
             // repeat this fps times per second using the timer class
             //   every time this is called, we update the arrays "timeData" and "fftData"
             Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                 self.runEveryInterval()
             }
             
             Timer.scheduledTimer(withTimeInterval: 1.0/5.0, repeats: true) { _ in
                 // set to opposite
                 self.pulseValue += 1
                 if self.pulseValue > 5{
                     self.pulseValue = 0
                 }
             }
             fileReader.play()
         }
     }
     
     func detectGesture() -> Gesture {
         guard baselineSet else { return .none }
         
         // Get current dominant frequency from FFT
         let currentFrequency = estimateDominantFrequency()
         
         // Calculate the frequency shift relative to the baseline
         let delta = currentFrequency - baselineFrequency
         
         // Detect toward or away gestures based on the threshold
         if delta > frequencyDeltaThreshold {
             return .toward
         } else if delta < -frequencyDeltaThreshold {
             return .away
         } else {
             return .none
         }
     }
     
     private func estimateDominantFrequency() -> Float {
         let minFrequency = 17000 // 17 kHz minimum
         let maxFrequency = 20000 // 20 kHz maximum
         
         let minIndex = Int(minFrequency * BUFFER_SIZE / samplingRate)
         let maxIndex = Int(maxFrequency * BUFFER_SIZE / samplingRate)
         
         var dominantIndex = minIndex // Renamed from maxIndex to avoid conflict
         var maxValue = fftData[minIndex]
         
         for index in minIndex...maxIndex where fftData[index] > maxValue {
             maxValue = fftData[index]
             dominantIndex = index
         }
         
         return Float(dominantIndex) * Float(samplingRate) / Float(BUFFER_SIZE)
     }
     
     func updateBaselineFrequency(_ frequency: Float) {
         baselineFrequency = frequency
         previousFrequency = frequency // Reset previous to prevent false detections
         frequencyBuffer.removeAll() // Clear any past readings in the buffer
         baselineSet = true
     }
     
     private func movingAverageFrequency(currentFrequency: Float) -> Float {
         // Add new frequency to buffer, limit buffer size to 10
         frequencyBuffer.append(currentFrequency)
         if frequencyBuffer.count > 10 {
             frequencyBuffer.removeFirst()
         }
         // Calculate the average of the buffer
         return frequencyBuffer.reduce(0, +) / Float(frequencyBuffer.count)
     }
     
     
     
     // You must call this when you want the audio to start being handled by our model
     func play(){
         if let manager = self.audioManager{
             manager.play()
         }
     }
     
     func stop(){
         if let manager = self.audioManager{
             manager.pause()
             manager.inputBlock = nil
             manager.outputBlock = nil
         }
         
         if let file = self.fileReader{
             file.pause()
             file.stop()
         }
         
         if let buffer = self.inputBuffer{
             buffer.clear() // just makes zeros
         }
         inputBuffer = nil
         fftHelper = nil
         fileReader = nil
     }
     
     
     //==========================================
     // MARK: Private Properties
     private lazy var audioManager:Novocaine? = {
         return Novocaine.audioManager()
     }()
     
     private lazy var fftHelper:FFTHelper? = {
         return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
     }()
     
     
     private lazy var inputBuffer:CircularBuffer? = {
         return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                    andBufferSize: Int64(BUFFER_SIZE))
     }()
     
     private lazy var fileReader:AudioFileReader? = {
             // find song in the main Bundle
             if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3"){
                 // if we could find the url for the song in main bundle, setup file reader
                 // the file reader is doing a lot here becasue its a decoder
                 // so when it decodes the compressed mp3, it needs to know how many samples
                 // the speaker is expecting and how many output channels the speaker has (mono, left/right, surround, etc.)
                 var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url,
                                                        samplingRate: Float(audioManager!.samplingRate),
                                                        numChannels: audioManager!.numOutputChannels)
                 
                 tmpFileReader!.currentTime = 0.0 // start from time zero!
                 
                 return tmpFileReader
             }else{
                 print("Could not initialize audio input file")
                 return nil
             }
         }()
     
     
     //==========================================
     // MARK: Private Methods
     // NONE for this model
     
     //==========================================
     // MARK: Model Callback Methods
     private func runEveryInterval(){
         if inputBuffer != nil {
             // copy time data to swift array
             self.inputBuffer!.fetchFreshData(&timeData, // copied into this array
                                              withNumSamples: Int64(BUFFER_SIZE))
             
             // now take FFT
             fftHelper!.performForwardFFT(withData: &timeData,
                                          andCopydBMagnitudeToBuffer: &fftData) // fft result is copied into fftData array
             
             // at this point, we have saved the data to the arrays:
             //   timeData: the raw audio samples
             //   fftData:  the FFT of those same samples
             // the user can now use these variables however they like
             
         }
     }
     
     //==========================================
     // MARK: Audiocard Callbacks
     // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
     // and in swift this translates to:
     private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
         // copy samples from the microphone into circular buffer
         self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
     }
     
     
     private func handleSpeakerQueryWithSinusoids(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
             if let arrayData = data, let manager = self.audioManager{
                 
                 var addFreq:Float = 0
                 var mult:Float = 1.0
                 if pulsing && pulseValue==1{
                     addFreq = 1000.0
                 }else if pulsing && pulseValue > 1{
                     mult = 0.0
                 }
                 
                 if let file = self.fileReader{
                     // get samples from audio file, pass array by reference
                     file.retrieveFreshAudio(arrayData,
                                 numFrames: numFrames,
                                 numChannels: numChannels)
                     
                     // adjust volume of audio file output
                     var volume:Float = mult*0.15 // zero out song also, if needed
                     vDSP_vsmul(arrayData, 1, &(volume), arrayData, 1, vDSP_Length(numFrames*numChannels))
                                     
                 }
                 
                 phaseIncrement = Float(2*Double.pi*Double(sineFrequency+addFreq)/manager.samplingRate)
                 
                 
                 var i = 0
                 let chan = Int(numChannels)
                 let frame = Int(numFrames)
                 if chan==1{
                     while i<frame{
                         arrayData[i] += (0.9*sin(phase))*mult
                         phase += phaseIncrement
                         if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                         i+=1
                     }
                 }else if chan==2{
                     let len = frame*chan
                     while i<len{
                         arrayData[i] += (0.9*sin(phase))*mult
                         arrayData[i+1] = arrayData[i]
                         phase += phaseIncrement
                         if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                         i+=2
                     }
                 }
                 
             }
         }
     
     
 }

 */
