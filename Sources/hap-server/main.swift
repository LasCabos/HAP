import Foundation
import func Evergreen.getLogger
import HAP
import SwiftyGPIO

fileprivate let logger = getLogger("demo")

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Dispatch
    import Glibc
#endif

getLogger("hap").logLevel = .off
getLogger("hap.encryption").logLevel = .off
logger.logLevel = .off

var neoHAPConfigURL = FileManager.default.homeDirectory(forUser: "pi")!.appendingPathComponent("NeoHAPConfiguration.json")

//MARK:- Process Command Line Arguments
let storage = FileStorage(filename: "configuration.json")
if CommandLine.arguments.contains("--recreate") {
    logger.info("Dropping all pairings, keys")
    try storage.write(Data())
    let _ = DeleteConfigFile(url: neoHAPConfigURL)
    print("Deleting NeoHAPConfig.json")
}

//MARK: - Check if we have a NeoConfig Stored
var configRead = ReadConfigFrom(url: neoHAPConfigURL)
var configModel = configRead.configModel
if(!configRead.success || !configRead.configModel.isFullyConfigured())
{
    print("We need to construct a valid configuration file. Please enter the following items")
    // ASK New Questions for configuration
    var deviceName:String?
    var numLEDs:Int?
    var deviceType: SupportedBoard?
    var colorCycleTime: Int?
    
    while(deviceName == nil || deviceName!.isEmpty){deviceName = AskQuestion(question: "Enter Device Name")}
    while(numLEDs == nil){numLEDs = Int(AskQuestion(question: "Number Of LEDs")!)}
    while(deviceType == nil){deviceType = SupportedBoard(rawValue: AskQuestion(question: "Device Type (RaspberryPi3, RaspberryPiPlusZero)")!)}
    while(colorCycleTime == nil){colorCycleTime = Int(AskQuestion(question: "Full color cycle time in minutes")!)}
    
    configModel = ConfigurationModel(name: deviceName!,
                                     numLEDs: numLEDs!,
                                     boardType: deviceType!,
                                     cycleTime: colorCycleTime!,
                                     recreate: false)
    
}

if (!configModel.isFullyConfigured()){
    print("Error: Configuration invalid. Stopping program.")
    exit(0)
}

if (!WriteConfigTo(url: neoHAPConfigURL, configModel: configModel)){
    print("Error: Could not write config file. Attempting to continue.")
}

let deviceSerialNumber = "00001"
let bridgeName = "Bridge"
let bridgeSerialNumber = "00001"


// MARK: - Setup Our Device
let neoLightbulb = Accessory.NeoLightbulb(info: Service.Info(name: configModel.name!,
                                          serialNumber: deviceSerialNumber),
                                          boardType: configModel.boardType!,
                                          numberOfLEDs: configModel.numLEDs!,
                                          cycleTime: configModel.cycleTime!)

let device = Device(
    bridgeInfo: Service.Info(name: bridgeName, serialNumber: bridgeSerialNumber),
    setupCode: "123-44-555",
    storage: storage,
    accessories: [neoLightbulb])

class MyDeviceDelegate: DeviceDelegate {
    func didRequestIdentificationOf(_ accessory: Accessory) {
        logger.info("Requested identification "
            + "of accessory \(String(describing: accessory.info.name.value ?? ""))")
    }

    func characteristic<T>(_ characteristic: GenericCharacteristic<T>,
                           ofService service: Service,
                           ofAccessory accessory: Accessory,
                           didChangeValue newValue: T?) {
        logger.info("Characteristic \(characteristic) "
            + "in service \(service.type) "
            + "of accessory \(accessory.info.name.value ?? "") "
            + "did change: \(String(describing: newValue))")
                
        if(accessory.serialNumber == deviceSerialNumber){
            
            //print("Main.swift: Characteristic Description: \(characteristic.description!)")
            if(characteristic.description! == "Hue"){
                neoLightbulb.hue = newValue as! Float
            }
            
            if(characteristic.description! == "Saturation"){
                neoLightbulb.saturation = newValue as! Float
            }
            
            if(characteristic.description! == "Brightness"){
                neoLightbulb.brightness = newValue as! Int
            }
            
            if(characteristic.description! == "Power State"){
                neoLightbulb.state = newValue as! Bool
            }
        }
    }

    func characteristicListenerDidSubscribe(_ accessory: Accessory,
                                            service: Service,
                                            characteristic: AnyCharacteristic) {
        logger.info("Characteristic \(characteristic) "
            + "in service \(service.type) "
            + "of accessory \(accessory.info.name.value ?? "") "
            + "got a subscriber")
    }

    func characteristicListenerDidUnsubscribe(_ accessory: Accessory,
                                              service: Service,
                                              characteristic: AnyCharacteristic) {
        logger.info("Characteristic \(characteristic) "
            + "in service \(service.type) "
            + "of accessory \(accessory.info.name.value ?? "") "
            + "lost a subscriber")
    }
}

var delegate = MyDeviceDelegate()
device.delegate = delegate
let server = try Server(device: device, listenPort: 8000)

// Stop server on interrupt.
var keepRunning = true
func stop() {
    DispatchQueue.main.async {
        logger.info("Shutting down...")
        keepRunning = false
        neoLightbulb.Cleanup()
    }
}
signal(SIGINT) { _ in stop() }
signal(SIGTERM) { _ in stop() }

print("Initializing the server...")

print()
print("Scan the following QR code using your iPhone to pair this device:")
print()
print(device.setupQRCode.asText)
print()

withExtendedLifetime([delegate]) {
    if CommandLine.arguments.contains("--test") {
        print("Running runloop for 10 seconds...")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))
    } else {
        while keepRunning {
            RunLoop.current.run(mode: .default, before: Date.distantFuture)
        }
    }
}

try server.stop()
logger.info("Stopped")




