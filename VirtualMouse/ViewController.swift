//
//  ViewController.swift
//  VirtualMouse
//
//  Created by exerhythm on 11/2/21.
//

import UIKit
import CoreMotion
import Peertalk
import PeertalkManager

class ViewController: UIViewController, PTManagerDelegate {
    let motion = CMMotionManager()
    var timer: Timer?
    var mngr = PTManager()
    var sendData = false
    var calTime: Double = 5
    var antiCal: (Double, Double,Double) = (0,0,0)
    
    var offset: (Double, Double,Double) = (0,0,0)
    
    var sens: (Double,Double) = {
        return (UserDefaults.standard.double(forKey: "xsens") + 1, UserDefaults.standard.double(forKey: "ysens") + 1)
    }()
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var gunModeSwitch: UISwitch!
    
    @IBOutlet weak var xsens: UISlider!
    @IBOutlet weak var ysens: UISlider!
    @IBAction func xsens(_ sender: UISlider) {
        sens.0 = Double(sender.value)
        UserDefaults.standard.set(sens.0 - 1, forKey: "xsens")
    }
    @IBAction func ysens(_ sender: UISlider) {
        sens.1 = Double(sender.value)
        UserDefaults.standard.set(sens.1 - 1, forKey: "ysens")
    }
    
    @IBAction func start(_ sender: UIButton) {
        if self.motion.isGyroAvailable && timer == nil {
            sender.setTitle("Calibrating...",for: [])
            startGyro()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (sendData ? 0.0 : calTime), execute: {
                self.antiCal = (self.offset.0 / 60 / self.calTime, self.offset.1 / 60 / self.calTime, self.offset.2 / 60 / self.calTime)
                print(self.offset)
                sender.setTitle("Stop VirtualMouse", for: [])
                self.sendData = true
            })
            
            
        } else {
            sender.setTitle("Start VirtualMouse", for: [])
            timer?.invalidate()
            timer = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mngr.delegate = self
        mngr.connect(portNumber: 2345)
        
        xsens.value = Float(sens.0)
        ysens.value = Float(sens.1)
        view.isMultipleTouchEnabled = true
    }
    
    fileprivate func startGyro() {
        motion.gyroUpdateInterval = 1/60
        motion.startGyroUpdates()
        
        timer = Timer(fire: Date(), interval: (1/60), repeats: true, block: { (timer) in
            if let data = self.motion.gyroData {
                if self.sendData {
                    self.gyroFire(data: data)
                } else {
                    self.offset = (self.offset.0 + data.rotationRate.x, self.offset.1 + data.rotationRate.y, self.offset.2 + data.rotationRate.z)
                    self.label.text = "calibration in progress"
                }
            }
        })
        
        RunLoop.current.add(timer!, forMode: .default)
    }
    func gyroFire(data: CMGyroData) {
        let x = data.rotationRate.x - antiCal.0
        let y = data.rotationRate.y - antiCal.1
        let z = data.rotationRate.z - antiCal.2
        self.label.text = "X:\(x)\nY:\(y)\nZ:\(z)"
        print(x,y,z)
        
        if !gunModeSwitch.isOn {
            self.mngr.send(data: "\(x * sens.1);\(y * sens.0);\(z)".data(using: .utf8)!, type: 100)
        } else {
            self.mngr.send(data: "\(-z * sens.1);\(x * sens.0);\(y)".data(using: .utf8)!, type: 100)
        }
    }
    
    
    func peertalk(shouldAcceptDataOfType type: UInt32) -> Bool {
        return true
    }
    
    func peertalk(didReceiveData data: Data?, ofType type: UInt32) {
        print(data ?? "none")
    }
    
    func peertalk(didChangeConnection connected: Bool) {
        print(connected)
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: view)
            if loc.x < view.frame.width / 2 {
                self.mngr.send(data: "down".data(using: .utf8)!, type: 101)
            } else{
                self.mngr.send(data: "down".data(using: .utf8)!, type: 102)
            }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: view)
            if loc.x < view.frame.width / 2 {
                self.mngr.send(data: "up".data(using: .utf8)!, type: 101)
            } else {
                self.mngr.send(data: "up".data(using: .utf8)!, type: 102)
            }
        }
    }
}
