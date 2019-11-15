
//
//  MartinsHelpers.swift
//  HAP
//
//  Created by MartinMcArthur on 2019-10-30.
//

import Foundation
import SwiftyGPIO


struct ConfigurationModel: Codable{
    var name:String?
    var numLEDs:Int?
    var boardType: SupportedBoard?
    var cycleTime: Int?
    var remoteESP8266s: [String]?
    var recreate: Bool = false
    
    enum CodingKeys: String, CodingKey{
        case name = "--name"
        case numLEDs = "--numLEDs"
        case boardType = "--boardType"
        case cycleTime = "--cycleTime"
        case remoteESP8266s = "--remoteESP8266s"
        case recreate = "recreate"
    }
    
    func isFullyConfigured() -> Bool{
        return !(name == nil || numLEDs == nil ||
            boardType == nil || cycleTime == nil)
    }
}

enum DataError:Error{
    case CouldNotDecode
}

extension Data
{
    func asConfigurationModel() throws -> ConfigurationModel
    {
        let decoder = JSONDecoder()
        guard let decodedJson = try? decoder.decode(ConfigurationModel.self, from: self)
            else{throw DataError.CouldNotDecode}
        return decodedJson
    }
}

extension ConfigurationModel
{
    func asData() -> (success:Bool, data:Data)
    {
        guard let temp = try? JSONEncoder().encode(self)
            else{return (false, Data())}
        
        return (true, temp)
    }
}


func AskQuestion(question: String) -> String?
{
    print("\(question)", terminator: ": ")
    let name = readLine()
    return name
    
}

func GenerateConfigModelWithCMDQuestions() -> ConfigurationModel
{
    print()
    print()
    print("----- Neopixel HAP Configuration ----")
    print("Config File: NeoHAPConfiguration.json")
    print()
    print("We need to construct a valid configuration file. Please enter the following items")
    print()
    // ASK New Questions for configuration
    var deviceName:String?
    var numLEDs:Int?
    var deviceType: SupportedBoard?
    var colorCycleTime: Int?
    var remoteESP8266s:[String]?
    
    while(deviceName == nil || deviceName!.isEmpty){deviceName = AskQuestion(question: "Enter Device Name")}
    while(numLEDs == nil){numLEDs = Int(AskQuestion(question: "Number Of LEDs")!)}
    while(deviceType == nil){deviceType = SupportedBoard(rawValue: AskQuestion(question: "Device Type (RaspberryPi3, RaspberryPiPlusZero)")!)}
    while(colorCycleTime == nil){colorCycleTime = Int(AskQuestion(question: "Full color cycle time in minutes")!)}
    while(remoteESP8266s == nil){
        let commaSeparatedString = AskQuestion(question: "Enter IP Adresses for any ESP8266 remote devices. Leave blank if there are no remote devices.\nExample: 192.168.2.55,192.168.2.63,...")
        
        let trimmed = commaSeparatedString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed?.components(separatedBy: ",")
        
        if(commaSeparatedString == nil || components == nil || trimmed == nil ||
            commaSeparatedString!.isEmpty || components!.isEmpty || trimmed!.isEmpty){
            
            remoteESP8266s = [String]()
        }
        else{
            remoteESP8266s = components
        }
    }
    
    let configModel = ConfigurationModel(name: deviceName!,
                                         numLEDs: numLEDs!,
                                         boardType: deviceType!,
                                         cycleTime: colorCycleTime!,
                                         remoteESP8266s: remoteESP8266s!,
                                         recreate: false)
    
    return configModel
}
