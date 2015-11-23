//
//  ViewController.swift
//  tstBt
//
//  Created by Круцких Олег on 22.11.15.
//  Copyright © 2015 Круцких Олег. All rights reserved.
//

import UIKit
import CoreBluetooth
import QuartzCore
import Swift


class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    var nexxHRMPeripheral: CBPeripheral? = nil
    var refreshTimer: NSTimer? = nil
    var attentionMin = false
    var attentionMax = false
    
    // Properties to hold data characteristics for the peripheral device
    var connected = ""
    var bodyData = ""
    var manufacturer = ""
    var nexxDeviceData = ""
    var heartRate: UInt16 = 0
    var avss: AVSS!
    var backgroundQueue: dispatch_queue_t!

    // Properties to handle storing the BPM and heart beat
    var heartRateBPM: UILabel? = nil
    var pulseTimer: NSTimer? = nil
    
    @IBOutlet weak var deviceInfo: UITextView!
    @IBOutlet weak var heartImage: UIImageView!
    
    @IBOutlet weak var minPulse: UITextField!
    @IBOutlet weak var maxPulse: UITextField!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        centralManager = CBCentralManager(delegate: self, queue: nil)
        avss = AVSS()
        refreshTimer = NSTimer(timeInterval: (60.0/60.0), target: self, selector: "doConnect", userInfo: nil, repeats: true)
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = UIColor.groupTableViewBackgroundColor()
        self.heartImage.image = UIImage(named: "HeartImage")
        
        // Clear out textView
        self.deviceInfo.text = ""
        self.deviceInfo.textColor = UIColor.blueColor()
        self.deviceInfo.backgroundColor = UIColor.groupTableViewBackgroundColor()
        self.deviceInfo.font = UIFont(name: "Futura-CondensedMedium", size: 25)
        self.deviceInfo.userInteractionEnabled = false
        
        // Create your Heart Rate BPM Label
        self.heartRateBPM = UILabel.init(frame: CGRectMake(85, 60, 85, 50))
        self.heartRateBPM!.textColor = UIColor.whiteColor()
        self.heartRateBPM!.text = "0";
        self.heartRateBPM!.font = UIFont(name: "Futura-CondensedMedium", size: 28)
        self.heartImage.addSubview(self.heartRateBPM!)
        
        // Scan for all available CoreBluetooth LE devices
        let services = [CBUUID(string: NEXX_HRM_HEART_RATE_SERVICE_UUID), CBUUID(string: NEXX_HRM_DEVICE_INFO_SERVICE_UUID)]
        //let centralManager: CBCentralManager = CBCentralManager(delegate: self, queue: nil)
        centralManager.scanForPeripheralsWithServices(services, options: nil)
        //self.centralManager = centralManager
        
        refreshTimer?.fire()
        dispatch_async(backgroundQueue, {
            while true {
                self.doConnect()
                self.sayWarning()
                sleep(5)
            }
        })
        
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWasShown:"), name:UIKeyboardWillShowNotification, object: nil)
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillHide:"), name:UIKeyboardWillHideNotification, object: nil)
    }
    
    func keyboardWasShown(notification: NSNotification) {
        var info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        
        UIView.animateWithDuration(0.1, animations: { () -> Void in
            self.view.frame.size.height -= keyboardFrame.size.height + 20
        })
    }
    func keyboardWillHide(notification: NSNotification) {
        var info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        
        UIView.animateWithDuration(0.1, animations: { () -> Void in
            self.view.frame.size.height += keyboardFrame.size.height + 20
        })
    }
    
    func sayWarning(){
        if (self.connected == "Connected: YES") {
            let tmr = NSNumber(unsignedShort: self.heartRate).integerValue
            if (tmr > Int(maxPulse.text!) && (attentionMax != true)) {
                self.avss.say("Пульс больше \(maxPulse.text!), уменьшите нагрузку.")
                attentionMin = false
                attentionMax = true
            }
            else if ((tmr < Int(minPulse.text!)) && (attentionMin != true)) {
                self.avss.say("Пульс меньше \(minPulse.text!), увеличьте нагрузку.")
                attentionMax = false
                attentionMin = true
            } else if ((tmr < Int(maxPulse.text!)) && (tmr > Int(minPulse.text!)) && (attentionMin || attentionMax)) {
                self.avss.say("Нагрузка нормализована.")
                attentionMin = false
                attentionMax = false
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //CBCentralManagerDelegate
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        peripheral.delegate = self
        //peripheral.discoverServices(nil)
        let connected = peripheral.state == CBPeripheralState.Connected ? "YES" : "NO"
        self.connected = "Connected: \(connected)"
        NSLog(self.connected);
        updateInfo()
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        let localName = advertisementData[CBAdvertisementDataLocalNameKey];
        if (localName?.length > 0) {
            NSLog("Found the heart rate monitor: \(localName)")
            self.centralManager.stopScan()
            self.nexxHRMPeripheral = peripheral
            peripheral.delegate = self
            self.centralManager.connectPeripheral(peripheral, options: nil)
        }
        updateInfo()
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        let connected = peripheral.state == CBPeripheralState.Connected ? "YES" : "NO"
        self.connected = "Connected: \(connected)"
        NSLog(self.connected);
        NSLog("didDisconnectPeripheral")
        updateInfo()
    }
    
    func doConnect(){
        if (self.connected != "Connected: YES") {
            let serviceUUIDs = [CBUUID(string: NEXX_HRM_HEART_RATE_SERVICE_UUID), CBUUID(string: NEXX_HRM_DEVICE_INFO_SERVICE_UUID)]
            let lastPeripherals = centralManager.retrieveConnectedPeripheralsWithServices(serviceUUIDs)
        
            if lastPeripherals.count > 0{
                if let device = lastPeripherals.last {
                    nexxHRMPeripheral = device
                    centralManager.connectPeripheral(nexxHRMPeripheral!, options: nil)
                    nexxHRMPeripheral?.discoverServices(serviceUUIDs)
                }
            }
            else {
                centralManager.scanForPeripheralsWithServices(serviceUUIDs, options: nil)
            }
        }
        updateInfo()
        //NSLog("doConnect")
        
    }
    
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        // Determine the state of the peripheral
        
        switch (central.state) {
        case .PoweredOff: NSLog("CoreBluetooth BLE hardware is powered off")
        case .PoweredOn:
            NSLog("CoreBluetooth BLE hardware is powered on and ready")
            doConnect()
        case .Unauthorized: NSLog("CoreBluetooth BLE state is unauthorized")
        case .Unknown: NSLog("CoreBluetooth BLE state is unknown")
        case .Unsupported: NSLog("CoreBluetooth BLE hardware is unsupported on this platform")
        default: NSLog("default")
        }
    }

    //CBPeripheralDelegate
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        for service in peripheral.services! {
            NSLog("Discovered service: \(service.UUID)")
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if (service.UUID == CBUUID(string: NEXX_HRM_HEART_RATE_SERVICE_UUID))  {  // 1
            for aChar in service.characteristics!
            {
                // Request heart rate notifications
                if (aChar.UUID == CBUUID(string: NEXX_HRM_MEASUREMENT_CHARACTERISTIC_UUID)) { // 2
                    self.nexxHRMPeripheral!.setNotifyValue(true, forCharacteristic: aChar)
                    NSLog("Found heart rate measurement characteristic");
                }
                // Request body sensor location
                else if (aChar.UUID == CBUUID(string:NEXX_HRM_BODY_LOCATION_CHARACTERISTIC_UUID)) { // 3
                    self.nexxHRMPeripheral!.readValueForCharacteristic(aChar)
                    NSLog("Found body sensor location characteristic")
                }
            }
        }
        // Retrieve Device Information Services for the Manufacturer Name
        if (service.UUID == CBUUID(string: NEXX_HRM_DEVICE_INFO_SERVICE_UUID))  { // 4
            for aChar in service.characteristics!
            {
                if (aChar.UUID == CBUUID(string: NEXX_HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID)) {
                    self.nexxHRMPeripheral!.readValueForCharacteristic(aChar)
                    NSLog("Found a device manufacturer name characteristic")
                }
            }
        }
    }
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        // Updated value for heart rate measurement received
        if (characteristic.UUID == CBUUID(string: NEXX_HRM_MEASUREMENT_CHARACTERISTIC_UUID)) { // 1
            // Get the Heart Rate Monitor BPM
            self.getHeartBPMData(characteristic, error: error)
        }
        // Retrieve the characteristic value for manufacturer name received
        if (characteristic.UUID == CBUUID(string: NEXX_HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID)) {  // 2
            self.getManufacturerName(characteristic)
        }
        // Retrieve the characteristic value for the body sensor location received
        else if (characteristic.UUID == CBUUID(string: NEXX_HRM_BODY_LOCATION_CHARACTERISTIC_UUID)) {  // 3
            self.getBodyLocation(characteristic)
        }
        
        updateInfo()
    }
    
    func updateInfo(){
        // Add your constructed device information to your UITextView
        self.deviceInfo.text = "\(self.connected)\n"
        self.heartRateBPM!.text = "\(self.heartRate) bpm"
        self.heartRateBPM!.font = UIFont(name: "Futura-CondensedMedium", size: 28)
    }
    
    
    //CBCharacteristic helpers
    func getHeartBPMData(characteristic: CBCharacteristic, error: NSError?){
        
        // Get the Heart Rate Monitor BPM
        var buffer = [UInt8](count: characteristic.value!.length, repeatedValue: 0x00)
        characteristic.value!.getBytes(&buffer, length: buffer.count)
        var bpm:UInt16 = 0
        
        if (buffer.count >= 2){
            if (buffer[0] & 0x01 == 0){
                bpm = UInt16(buffer[1]);
            }else {
                bpm = UInt16(buffer[1]) << 8
                bpm =  bpm | UInt16(buffer[2])
            }
        }
        
        
        // Display the heart rate value to the UI if no error occurred
        if ((characteristic.value != nil) || (error != nil)) {   // 4
            self.heartRate = bpm
            updateInfo()
            self.doHeartBeat()
            let tmr = NSNumber(unsignedShort: self.heartRate).doubleValue
            self.pulseTimer = NSTimer(timeInterval: (60.0 / tmr), target: self, selector: "doHeartBeat", userInfo: nil, repeats: false)
            //NSLog("getHeartBPMData, tmr = \(tmr)")
        }
        return;
    }
    func getManufacturerName(characteristic: CBCharacteristic){
        let manufacturerName = NSString(data: characteristic.value!, encoding: NSUTF8StringEncoding) // 1
        self.manufacturer = "Manufacturer: \(manufacturerName)"    // 2
        return;
    }
    func getBodyLocation(characteristic: CBCharacteristic){
        //let sensorData = characteristic.value         // 1
        var bodyData = [UInt8](count: characteristic.value!.length, repeatedValue: 0x00)
        characteristic.value!.getBytes(&bodyData, length: bodyData.count)
        
        
        if (bodyData.count >= 2) {
            let bodyLocation = bodyData[0]  // 2
            let loc = bodyLocation == 1 ? "Chest" : "Undefined"
            self.bodyData = "Body Location: \(loc)" // 3
        }
        else {  // 4
            self.bodyData = "Body Location: N/A"
        }
        return;
    }
    func doHeartBeat(){
        
        let layer = self.heartImage.layer
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.toValue = NSNumber(float: 1.1)
        pulseAnimation.fromValue = NSNumber(float: 1.0)
        
        let tmr = NSNumber(unsignedShort: self.heartRate).doubleValue
        
        pulseAnimation.duration = 60.0 / tmr / 2.0
        pulseAnimation.repeatCount = 1
        pulseAnimation.autoreverses = true
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
        layer.addAnimation(pulseAnimation, forKey: "scale")
        
        self.pulseTimer = NSTimer(timeInterval: (60.0 / tmr), target: self, selector: "doHeartBeat", userInfo: nil, repeats: false)
        //NSLog("doHeartBeat, tmr = \()")
    }
    func doHeartBeat1(){
        NSLog("doHeartBeat1")
    }
    
    @IBAction func tapToHeart(sender: UITapGestureRecognizer) {
        refreshTimer?.fire()
        if (self.heartRate == 0) {
            avss.say("Ваш пульс равен нулю. Возможно вы труп?")
        }
        else {
            avss.say("Ваш пульс равен \(self.heartRate)")
        }
    }

    
    

}

