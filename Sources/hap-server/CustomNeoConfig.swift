//
//  CustomNeoConfig.swift
//  hap-server
//
//  Created by MartinMcArthur on 2019-10-23.
//

import Foundation
import SwiftyGPIO

/// Created by Martin McArthur
/// This class stores the the PiType and Number of leds.
/// This class can be populated by reading the JSON file or from the command line
class CustomNeoConfig{
    
    var boardType:SupportedBoard?
    var numLEDs:Int?
    var isValid:Bool{
           get{
            return (boardType == nil || numLEDs == nil) ? false : true
           }
       }
    private var fileURL: URL!
   
    
    init() {
        fileURL = FileManager.default.homeDirectory(forUser: "pi")?.appendingPathComponent("NeoHAPConfig.json")
    }
    
    
    /// Reads CustomConfig Settings from command line arguments
    /// - Parameter commandLineArguments: supported command line arguments
    func ReadFrom(commandLineArguments: [String]) -> Bool
    {
        if commandLineArguments.contains("--config") || commandLineArguments.contains("-c")
        {
            for i in 0..<commandLineArguments.count{
                if (commandLineArguments[i] == "--config" || commandLineArguments[i] == "-c")
                {
                    if ((i+1) > commandLineArguments.count || (i+2) > commandLineArguments.count){
                        return false
                    }
                    
                    self.boardType = ConvertToSupportedBoard(commandLineAgrument: commandLineArguments[i+1])
                    self.numLEDs = Int(commandLineArguments[i+2])
                }
            }
        }
        return self.isValid
    }
    
    
    /// Reads the CustomConfigSettings from JSON File
    func ReadJSON() -> Bool{
        struct JsonCoding: Codable{
            let boardType: SupportedBoard
            let numLEDs: Int
            
            enum CodingKeys: String, CodingKey{
                case boardType = "BoardType"
                case numLEDs = "NumLEDs"
            }
        }
        
        do{
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let jsonCoding = try decoder.decode(JsonCoding.self, from: data)
            boardType = jsonCoding.boardType
            numLEDs = jsonCoding.numLEDs
        }
        catch{
            print("Failed")
            return false
        }
        
        return true
    }
    
    
    /// Writes CustomConfig Settings to JSON file
    func WriteJSON() -> Bool{
        
        if(boardType == nil || numLEDs == nil){return false}
        
        let jsonObject:[String:Any] = ["BoardType":boardType!.rawValue, "NumLEDs":numLEDs]

        do{
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
        }
        catch{
            print("Failed")
            return false
        }
        
        return true
    }
    
    
    /// Helper function to convert command line argument to SupportedBoardEnumType
    /// - Parameter commandLineAgrument: single command line argument to convert to board type
    private func ConvertToSupportedBoard(commandLineAgrument: String) -> SupportedBoard?{
        if(commandLineAgrument == "0" ||
            commandLineAgrument.lowercased() == "rpizero" ||
            commandLineAgrument.lowercased() == "zero" ||
            commandLineAgrument.lowercased() == "rpi0"){

            return SupportedBoard.RaspberryPiPlusZero
        }
        else if(commandLineAgrument == "3" ||
                commandLineAgrument.lowercased() == "rpithree" ||
                commandLineAgrument.lowercased() == "three" ||
                commandLineAgrument.lowercased() == "rpi3"){

            return SupportedBoard.RaspberryPi3
        }
        else {return nil}
    }
}
