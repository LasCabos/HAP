//
//  MartinsHelpers.swift
//  HAP
//
//  Created by MartinMcArthur on 2019-10-30.
//

import Foundation
import SwiftyGPIO
//import SPMUtility


struct ConfigurationModel: Codable{
    var name:String?
    var numLEDs:Int?
    var boardType: SupportedBoard?
    var cycleTime: Int?
    var recreate: Bool = false
    
    enum CodingKeys: String, CodingKey{
        case name = "--name"
        case numLEDs = "--numLEDs"
        case boardType = "--boardType"
        case cycleTime = "--cycleTime"
        case recreate = "recreate"
    }
    
    public func Merge(withConfig:ConfigurationModel) -> ConfigurationModel
    {
        var newConfigModel = self
        if(self.name == nil){
            newConfigModel.name = withConfig.name
        }
        if(self.numLEDs == nil){
            newConfigModel.numLEDs = withConfig.numLEDs
        }
        if(self.cycleTime == nil){
            newConfigModel.cycleTime = withConfig.cycleTime
        }
        if(self.boardType == nil){
            newConfigModel.boardType = withConfig.boardType
        }
        newConfigModel.recreate = withConfig.recreate
        
        return newConfigModel
    }
    
    func isFullyConfigured() -> Bool{
        return !(name == nil || numLEDs == nil ||
            boardType == nil || cycleTime == nil)
    }
}

//func ParseCommandLineArguments(commandLineArgs: [String]) -> (success: Bool, configModel: ConfigurationModel)
//{
//    let parser = ArgumentParser(commandName: "hap-server", usage:  "[options]", overview: "HAP-Sever NeoLight allows control of NeoPixel light bulbs attached to a RaspberryPi")
//
//    let recreateOpt:PositionalArgument<String> = parser.add(positional: ConfigurationModel.CodingKeys.recreate.rawValue, kind: String.self, optional: true, usage: "Recreate HAP device profile", completion: ShellCompletion.none)
//
//    let nameOpt = parser.add(option: ConfigurationModel.CodingKeys.name.rawValue, shortName: "-n", kind: String.self, usage: "Custom name for device.", completion: ShellCompletion.none)
//
//    let numOpt = parser.add(option: ConfigurationModel.CodingKeys.numLEDs.rawValue, shortName: "-l", kind: Int.self, usage: "The number of NeoPixel LEDs on the board.", completion: ShellCompletion.none)
//
//    let typOpt = parser.add(option: ConfigurationModel.CodingKeys.boardType.rawValue,
//                            shortName: "-t",
//                            kind: String.self,
//                            usage: "The type of RPi device. (\(SupportedBoard.RaspberryPi3), \(SupportedBoard.RaspberryPiPlusZero))",
//        completion: ShellCompletion.none)
//
//    let cycleOpt = parser.add(option: ConfigurationModel.CodingKeys.cycleTime.stringValue, shortName: "-c", kind: Int.self, usage: "Full color cycle in minuets", completion: ShellCompletion.none)
//
//
//    guard let parserResult = try? parser.parse(Array(commandLineArgs.dropFirst()))
//        else{return (false, ConfigurationModel())}
//
//    var configModel = ConfigurationModel()
//
//    configModel.name = parserResult.get(nameOpt)
//    configModel.numLEDs = parserResult.get(numOpt)
//    configModel.cycleTime = parserResult.get(cycleOpt)
//
//    let type = parserResult.get(typOpt)
//    if(type != nil && !type!.isEmpty){
//        configModel.boardType = SupportedBoard(rawValue: type!)
//    }
//
//    configModel.recreate = (parserResult.get(recreateOpt) != nil) ? true : false
//
//    return (true, configModel)
//}

func ReadConfigFrom(url: Foundation.URL) -> (success: Bool, configModel: ConfigurationModel)
{
    guard let data = try? Data(contentsOf: url)
        else{return (false, ConfigurationModel())}
    
    
    let decoder = JSONDecoder()
    guard let decodedJson = try? decoder.decode(ConfigurationModel.self, from: data)
        else{return (false, ConfigurationModel())}
    
    return (true, decodedJson)
}

func WriteConfigTo(url: Foundation.URL, configModel: ConfigurationModel) -> Bool
{
    guard let temp = try? JSONEncoder().encode(configModel)
        else{return false}
    
    guard let _ = try? temp.write(to: url)
        else{return false}
    
    return true
}

func DeleteConfigFile(url: Foundation.URL) -> Bool
{
    do{
        try FileManager.default.removeItem(at: url)
        return true
    }
    catch{
        return false
    }
}

func AskQuestion(question: String) -> String?
{
    print("\(question)", terminator: ": ")
    let name = readLine()
    return name
    
}


