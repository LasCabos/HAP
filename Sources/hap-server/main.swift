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

getLogger("hap").logLevel = .debug
getLogger("hap.encryption").logLevel = .warning

//MARK:- Process Command Line Arguments
let storage = FileStorage(filename: "configuration.json")
if CommandLine.arguments.contains("--recreate") {
    logger.info("Dropping all pairings, keys")
    try storage.write(Data())
}

if CommandLine.arguments.contains("--help") ||
    CommandLine.arguments.contains("-h"){
    print("--- Help Info ----")
    print("")
    print("The following commands are supported:")
    print("[--recreate] Will reset the device configuration and allow new paring with Homekit")
    print("[--config][-c] This will allow the configuration of the NeoPixel Device. It requires two non-optional strings")
    print("Example: --config BoardType NumLEDs")
    print("Example: --config Rpi0 144")
    print("/t/t The following are supported board types:")
    print("/t/t/t RPiZero: 0, rpizero, zero, rpi0")
    print("/t/t/t RPi3:    3, rpithree, three, rpi3")
    print("---- End Help ----")
    print("")
    
    exit(0)
}

var neoDeviceConfig = CustomNeoConfig()

if(CommandLine.arguments.contains("--config") || CommandLine.arguments.contains("-c"))
{
    let isValid = neoDeviceConfig.ReadFrom(commandLineArguments: CommandLine.arguments)
    if(isValid){
        let didWrite = neoDeviceConfig.WriteJSON()
        if(!didWrite){
            print("Could not write JSON Config. Please contact your administrator.")
            exit(0)
        }
    }
    else{
        print("Could not read from command line arguments. They must be invalid. Use -h or --help.")
        exit(0)
    }
}
else if(neoDeviceConfig.ReadJSON()) //If we havent set a config lets try to read from JSON
{
    if(!neoDeviceConfig.isValid){
        print("The configuration file is not valid. Please set a new configuration using the --config/-c command line options. Please see --help/-h for more information")
    }
}
else
{
    print("You have not set a configuration with --config/-c or have a previously stored configuration.json file. The software will now exit. Please see --help for more information.")
}


let deviceName = "Light"
let deviceSerialNumber = "00001"//String(Int.random(in: 1 ..< 99999))
let bridgeName = "Bridge"
let bridgeSerialNumber = "00001"//String(Int.random(in: 1 ..< 99999))

//let livingRoomLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Living Room", serialNumber: "00002"))
//let bedroomNightStand = Accessory.Lightbulb(info: Service.Info(name: "Bedroom", serialNumber: "00003"))

// MARK: - Setup Our Device
let neoLightbulb = Accessory.NeoLightbulb(info: Service.Info(name: deviceName, serialNumber: deviceSerialNumber), boardType: neoDeviceConfig.boardType!, numberOfLEDs: neoDeviceConfig.numLEDs!)

let device = Device(
    bridgeInfo: Service.Info(name: bridgeName, serialNumber: bridgeSerialNumber),
    setupCode: "123-44-555",
    storage: storage,
    accessories: [
        neoLightbulb
//        Accessory.Door(info: Service.Info(name: "Front Door", serialNumber: "00005")),
//        Accessory.Switch(info: Service.Info(name: "Garden Lights", serialNumber: "00006")),
//        Accessory.Thermostat(info: Service.Info(name: "Living Room Thermostat", serialNumber: "00007")),
//        Accessory.Thermometer(info: Service.Info(name: "Office Thermometer", serialNumber: "00008")),
//        Accessory.Outlet(info: Service.Info(name: "Coffee Machine", serialNumber: "00009")),
//        Accessory.Window(info: Service.Info(name: "Toilet Window", serialNumber: "00010")),
//        Accessory.WindowCovering(info: Service.Info(name: "Shades", serialNumber: "00011")),
//        Accessory.Fan(info: Service.Info(name: "Living Room Ceiling Fan", serialNumber: "00012")),
//        Accessory.GarageDoorOpener(info: Service.Info(name: "Garage", serialNumber: "00013")),
//        Accessory.LockMechanism(info: Service.Info(name: "Front Door Lock", serialNumber: "00014")),
//        Accessory.SecuritySystem(info: Service.Info(name: "Alarm", serialNumber: "00015"))
    ])

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
            
            print("Main.swift: Characteristic Description: \(characteristic.description!)")
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
    }
}
signal(SIGINT) { _ in stop() }
signal(SIGTERM) { _ in stop() }

print("Initializing the server...")

// Switch the lights every 5 seconds.
//let timer = DispatchSource.makeTimerSource()
//timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(5))
//timer.setEventHandler(handler: {
//    livingRoomLightbulb.lightbulb.powerState.value = !(livingRoomLightbulb.lightbulb.powerState.value ?? false)
//})
//timer.resume()

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




