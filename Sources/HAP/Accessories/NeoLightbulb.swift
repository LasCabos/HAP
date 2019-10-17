// swiftlint:disable nesting
import Foundation
import WS281x
import SwiftyGPIO

extension Accessory {
    open class NeoLightbulb: Accessory {
        
        // Three types of Lightbulb
        //  - monochrome    Single color bulb
        //  - color         Color Hue and Saturation can be varied
        //  - colorTemperature(min, max)
        //                  The color temperature in reciprical microkelvin
        //                  1,000,000/(Kelvin). min and max values must
        //                  be within HAP permissible range 50...400
        public enum ColorType {
            case monochrome
            case color
            case colorTemperature(min: Double, max: Double)
        }
        
        public enum ColorMode {
            case single
            case multi
        }
        
        private let neoLightBulbService: Service.NeoLightbulbService!
        private var colorMode: ColorMode!
        private var numLEDs: Int!
        private var ws281x: WS281x!
        private var lastColorChangeDate = Date()
        
        private var temp_count = 0
        private var cycleColorTimer: Timer?
        private var previous4Colors = [NeoColor.red, NeoColor.green, NeoColor.blue, NeoColor.white] // This keeps track of the previous 4 colors for color cycle. To enable color cycle you must send command color1, color2, color1, color2
        
        // Default Lightbulb is a simple monochrome bulb
        public init(info: Service.Info,
                    additionalServices: [Service] = [],
                    boardType: SupportedBoard,
                    numberOfLEDs: Int,
                    type: ColorType = .color,
                    isDimmable: Bool = true)
        {
            
            self.numLEDs = numberOfLEDs
            
            let pwms = SwiftyGPIO.hardwarePWMs(for: boardType)!
            let gpio = (pwms[0]?[.P18])!
            self.ws281x = WS281x(gpio, type: .WS2812B, numElements: self.numLEDs)

            neoLightBulbService = Service.NeoLightbulbService(type: type, isDimmable: isDimmable)
            colorMode = .single
            super.init(info: info, type: .lightbulb, services: [neoLightBulbService] + additionalServices)
            
            self.hue = 360
            self.saturation = 100
            self.brightness = 100
        }
        
        
        // MARK: - Return Functions
        public var hue: Float? {
            get {
                return self.neoLightBulbService.hue?.value
            }
            set {
                print("Hue")
                self.neoLightBulbService.hue?.value = newValue
                self.ApplyColorChange(color: self.currentColor, shouldWait: true)
            }
        }
        
        public var saturation: Float? {
            get {
                return self.neoLightBulbService.saturation?.value
            }
            set {
                print("Sat")
                self.neoLightBulbService.saturation?.value = newValue
                self.ApplyColorChange(color: self.currentColor, shouldWait: true)
            }
        }
        
        public var brightness: Int? {
            get {
                return self.neoLightBulbService.brightness?.value
            }
            set {
                print("Brightness")
                self.neoLightBulbService.brightness?.value = newValue
                self.ApplyColorChange(color: self.currentColor, shouldWait: true)
            }
        }
        
        public var state: Bool? {
            get {
                return self.neoLightBulbService.powerState.value
            }
            set {
                print("State")
                self.neoLightBulbService.powerState.value = newValue
                ChangeDeviceState(state: newValue!)
                
            }
        }
        
        public var mode: ColorMode{
            get {return self.colorMode}
        }
        
        
        // MARK: - Utility functions to change color of lights
        private var currentColor: NeoColor{
            get{
                return NeoColor(degrees: self.hue!, percent: self.saturation!, percent: Float(self.brightness!))
            }
        }
        
        private func ChangeDeviceState(state:Bool){
            if(state){
                self.ApplyColorChange(color: self.currentColor, shouldWait: true)
            }
            else{
                self.ApplyColorChange(color: NeoColor.black, shouldWait: true)
            }
        }
        
        
        /// Manages color change if should be single or multi
        private func ApplyColorChange(color: NeoColor, shouldWait: Bool){
            
            print("ColorChange")
            let previousColorChangeDate = self.lastColorChangeDate
            let newColorChangeDate = Date()
            let deltaTime = newColorChangeDate.timeIntervalSinceReferenceDate - previousColorChangeDate.timeIntervalSinceReferenceDate
            self.lastColorChangeDate = newColorChangeDate
            
            
            
            // 2 - 5 seconds between color changes will result in a multicolor
            if( 2 < deltaTime || deltaTime > 5 ){
                //Single Color
                print("Single Color")
                self.SetAllPixelsTo(color: color, shouldWait: shouldWait)
            }
            else{
                // Multi Color
                print("Multi Color - Disabled - setting single color")
                self.SetAllPixelsTo(color: color, shouldWait: shouldWait)
            }
        }
        
        
        /// Sets all the pixels of the device to a color
        ///
        /// - Parameters:
        ///   - color: the color to change the pixels to
        ///   - shouldWait: (blocking) if we should wait for all pixels to be set
        private func SetAllPixelsTo(color: NeoColor, shouldWait: Bool){
  
           // CycleColors(color1: NeoColor.red, color2: NeoColor.blue)
            
            self.lastColorChangeDate = Date()
            print("SetColor: \(color.CombinedUInt32)")
            let initial = [UInt32](repeating: color.CombinedUInt32, count: self.numLEDs)
            self.ws281x.setLeds(initial)
            ws281x.start()
            if(shouldWait){ws281x.wait()} // Blocking
        }
        
        private func CycleColors(color1: NeoColor, color2: NeoColor)
        {
            
            
        }
        
        private func StartCycleColorTimer(withTimeInterval: TimeInterval)
        {
            // Lambda
            func RunTimer(withInterval: TimeInterval)
            {
                cycleColorTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true, block: { (Timer) in
                    print("CycleColor: \(self.temp_count)")
                    self.temp_count += 1
                })
            }
            
            if(self.cycleColorTimer == nil)
            {
                RunTimer(withInterval: withTimeInterval)
            }
            else
            {
                StopCycleColorTimer()
                RunTimer(withInterval: withTimeInterval)
            }
        }
        
        private func StopCycleColorTimer()
        {
            if(self.cycleColorTimer == nil) {return}
            if(self.cycleColorTimer!.isValid)
            {
                self.cycleColorTimer!.invalidate()
                self.cycleColorTimer! = nil
                print("Invalidated Timer")
            }
        }
        
        
        /// Determines if we should be in color cycle mode. ColorCycle Mode is valid if the user
        /// enters color1, color2, color1, color2. The cycle should begin
        private func ValidateColorCycle() -> Bool
        {
            return (previous4Colors[0] == previous4Colors[2] &&
            previous4Colors[1] == previous4Colors[3]) ? true : false
        }
        
//        // MARK: Cycle Colors
//        // This needs to be in an event loop somehow
//        private func CycleColors(color1: NeoColor, color2: NeoColor)
//        {
//            let color1 = NeoColor(red: red1, green: green1, blue: blue1)
//            let color2 = NeoColor(red: red2, green: green2, blue: blue2)
//
//            self.primaryColor = color1
//            self.secondaryColor = color2
//            let _ = self.WriteConfigToFileSystem()
//
//            if(eventLoop.state == .resumed){eventLoop.suspend()}
//            if(self.state == 0){return "Success"} // We dont need to start the loop if our lights are off.
//
//            // Lets cycle our color
//            var cycleColor  = color1
//            var startColor  = color1
//            var endColor    = color2
//
//            let fullTransitionInSeconds:Float = 60.0 * 5.0
//            let totalRefreshCount = fullTransitionInSeconds / Float(eventLoop.timeInterval)
//
//            eventLoop.eventHandler = {
//
//                let deltaColor = startColor - endColor
//                let hueInc = deltaColor!.hsv.h / totalRefreshCount
//                let satInc = deltaColor!.hsv.s / totalRefreshCount
//                let brightInc = deltaColor!.hsv.v / totalRefreshCount
//                let IncColor = NeoColor(hue: hueInc, saturation: satInc, brightness: brightInc)
//
//                cycleColor = (cycleColor - IncColor)!
//
//                if(cycleColor == endColor){
//                    print("Switch Direction")
//                    swap(&startColor, &endColor)
//                }
//
//                print("\(cycleColor.CombinedUInt32)")
//                self.SetAllPixelsTo(color: cycleColor, shouldWait: false,  honorDeviceState: true)
//            }
//            eventLoop.resume()
//        }
       
    }
}

extension Service {
    open class NeoLightbulbService: LightbulbBase {
        
        public init(type: Accessory.NeoLightbulb.ColorType, isDimmable: Bool) {
            var characteristics: [AnyCharacteristic] = []
            
            if isDimmable {
                characteristics.append(.brightness())
            }
            
            switch type {
            case .color:
                characteristics.append(.hue())
                characteristics.append(.saturation())
            case .colorTemperature(let min, let max):
                precondition(min >= 50 && max <= 400,
                             "Maximum range for color temperature is 50...400, \(min)...\(max) is out of bounds")
                characteristics.append(.colorTemperature(maxValue: max, minValue: min))
            default:
                break
            }
            super.init(characteristics: characteristics)
        }
    }
}

//
//  NeoColor.swift
//  led-blink
//
//  Created by MartinMcArthur on 2018-11-20.
//
extension NeoColor{
    func ConvertToCommandStringColor() -> String
    {
        let red     = Int(self.m_redComponent * 255)
        let green   = Int(self.m_greenComponent * 255)
        let blue    = Int(self.m_blueComponenet * 255)
        
        let returnString = String("\(red) \(green) \(blue)")
        return returnString
    }
}

// MARK: - Classes
public class NeoColor:Equatable{
    
    public static func == (lhs: NeoColor, rhs: NeoColor) -> Bool {
        return (lhs.CombinedUInt32 == rhs.CombinedUInt32) ? true : false
    }
    
    public static func -(lhs:NeoColor, rhs:NeoColor) -> NeoColor!
    {
        // We are going to assume the saturation and brighness will be maxed
        let deltaHue = lhs.hsv.h - rhs.hsv.h
        let deltaBright = lhs.hsv.v - rhs.hsv.v
        let deltaSat = lhs.hsv.s - rhs.hsv.s
        
        return NeoColor(hue: deltaHue, saturation: deltaSat, brightness: deltaBright)
    }
    
    public static func +(lhs:NeoColor, rhs:NeoColor) -> NeoColor!
    {
        // We are going to assume the saturation and brighness will be maxed
        let sumHue = lhs.hsv.h + rhs.hsv.h
        let sumBright = lhs.hsv.v + rhs.hsv.v
        let sumSat = lhs.hsv.s + rhs.hsv.s
        
        return NeoColor(hue: sumHue, saturation: sumSat, brightness: sumBright)
    }
    
    
    private var m_redComponent:Float    = 0 // 0 - 1
    private var m_greenComponent:Float  = 0 // 0 - 1
    private var m_blueComponenet:Float  = 0 // 0 - 1
    private var m_hue:Float             = 0 // 0 - 360
    private var m_saturation:Float      = 0 // 0 - 1
    private var m_brightness:Float      = 0 // 0 - 1
    
    // Values 0.0-1.0
    init(red: Float, green: Float, blue: Float) {
        m_redComponent = red
        m_greenComponent = green
        m_blueComponenet = blue
        
        let rgb = RGB(r: red, g: green, b: blue)
        let hsv = rgb.hsv
        
        m_hue = hsv.h
        m_saturation = hsv.s
        m_brightness = hsv.v
    }
    
    
    /// Creates NeoColor from Hue (0-360) Sat(0-100) Brightness(0-100) using percentages
    ///
    /// - Parameters:
    ///   - hue: 0-360
    ///   - sat: 0-100
    ///   - brightness: 0-100
    init(degrees hue: Float, percent saturation: Float, percent brightness: Float){
        
        m_hue = hue
        m_saturation = saturation / 100
        m_brightness = brightness / 100
        
        let hsv = HSV(h: m_hue, s: m_saturation, v: m_brightness)
        let rgb = hsv.rgb
        
        m_redComponent      = rgb.r
        m_greenComponent    = rgb.g
        m_blueComponenet    = rgb.b
    }
    
    /// Creates NeoColor from Hue(0-360) Sat(0-1) Brightness(0-1)
    ///
    /// - Parameters:
    ///   - hue: 0-360
    ///   - saturation: 0-1
    ///   - brightness: 0-1
    init(hue: Float, saturation: Float, brightness: Float)
    {
        m_hue = hue
        m_saturation = saturation
        m_brightness = brightness
        
        let hsv = HSV(h: hue, s: saturation, v: brightness)
        let rgb = hsv.rgb
        
        m_redComponent      = rgb.r
        m_greenComponent    = rgb.g
        m_blueComponenet    = rgb.b
    }
    
    // Values 0 - 255
    init(red:Int, green:Int, blue:Int)
    {
        m_redComponent = Float(red)/255.0
        m_greenComponent = Float(green)/255.0
        m_blueComponenet = Float(blue)/255.0
        
        let rgb = RGB(r: m_redComponent, g: m_greenComponent, b: m_blueComponenet)
        let hsv = rgb.hsv
        
        m_hue = hsv.h
        m_saturation = hsv.s
        m_brightness = hsv.v
    }
    
    init(combinedColor:UInt32)
    {
        let red = combinedColor >> 16
        let green = combinedColor >> 8 & 0xFF
        let blue = combinedColor & 0xFF
        
        m_redComponent = Float(Float(red)/255.0)
        m_greenComponent = Float(Float(green)/255.0)
        m_blueComponenet = Float(Float(blue)/255.0)
        
        let rgb = RGB(r: m_redComponent, g: m_greenComponent, b: m_blueComponenet)
        let hsv = rgb.hsv
        
        m_hue = hsv.h
        m_saturation = hsv.s
        m_brightness = hsv.v
    }
    
    /// Returns RGB struct
    var rgb:RGB{
        get { return RGB(r: m_redComponent, g: m_greenComponent, b: m_blueComponenet)}
    }
    
    /// Returns HSV struct
    var hsv:HSV{
        get { return HSV(h: m_hue, s: m_saturation, v: m_brightness)}
    }
    
    /// Returns a combined UInt32 specifically for passing to WS281X color
    var CombinedUInt32:UInt32
    {
        get{
            
            let red     = (m_redComponent * 100).rounded() / 100
            let green   = (m_greenComponent * 100).rounded() / 100
            let blue    = (m_blueComponenet * 100).rounded() / 100
            
            let red_t   = UInt32(red * 255) << 16
            let green_t = UInt32(green * 255) << 8
            let blue_t  = UInt32(blue * 255)
            
            let comb:UInt32 = red_t + green_t + blue_t
            return comb
        }
    }
    
    // Returns a hex string representing the color
    var HexString: String
    {
        get{ return (String(format: "%02X", self.CombinedUInt32))}
    }
    
    public func PrintRGBandHSV(label:String = "N/A"){
        print("\(label): R: \(rgb.r) G: \(rgb.g) B: \(rgb.b)    H: \(hsv.h) S: \(hsv.s) V\(hsv.v)")
    }
    
    //Basic Colors
    public static var red:NeoColor     {get {return NeoColor(red: 1.0, green: 0.0,   blue: 0.0)}}
    public static var green:NeoColor   {get {return NeoColor(red: 0.0,   green: 1.0, blue: 0.0)}}
    public static var blue:NeoColor    {get {return NeoColor(red: 0.0,   green: 0.0,   blue: 1.0)}}
    public static var white:NeoColor   {get {return NeoColor(red: 1.0, green: 1.0, blue: 1.0)}}
    public static var black:NeoColor   {get {return NeoColor(red: 0.0,   green: 0.0,   blue: 0.0)}}
    public static var grey:NeoColor     {get {return NeoColor(red: 166, green: 166, blue: 166)}}
    public static var randomColor:NeoColor
    { get{
        let red = Int.random(in: 0 ..< 255)
        let green = Int.random(in: 0 ..< 255)
        let blue = Int.random(in: 0 ..< 255)
        return NeoColor(red: red, green: green, blue: blue)
        }
    }
}

//MARK: - RGBtoHSV
// https://www.cs.rit.edu/~ncs/color/t_convert.html
struct RGB {
    // Percent
    let r: Float // [0,1]
    let g: Float // [0,1]
    let b: Float // [0,1]
    
    static func hsv(r: Float, g: Float, b: Float) -> HSV {
        let min = r < g ? (r < b ? r : b) : (g < b ? g : b)
        let max = r > g ? (r > b ? r : b) : (g > b ? g : b)
        
        let v = max
        let delta = max - min
        
        guard delta > 0.00001 else { return HSV(h: 0, s: 0, v: max) }
        guard max > 0 else { return HSV(h: -1, s: 0, v: v) } // Undefined, achromatic grey
        let s = delta / max
        
        let hue: (Float, Float) -> Float = { max, delta -> Float in
            if r == max { return (g-b)/delta } // between yellow & magenta
            else if g == max { return 2 + (b-r)/delta } // between cyan & yellow
            else { return 4 + (r-g)/delta } // between magenta & cyan
        }
        
        let h = hue(max, delta) * 60 // In degrees
        
        return HSV(h: (h < 0 ? h+360 : h) , s: s, v: v)
    }
    
    static func hsv(rgb: RGB) -> HSV {
        return hsv(r: rgb.r, g: rgb.g, b: rgb.b)
    }
    
    var hsv: HSV {
        return RGB.hsv(rgb: self)
    }
    
    var PrintableString: String {
        return "R: \(self.r) G: \(self.g) B: \(self.b)"
    }
}

struct RGBA {
    let a: Float
    let rgb: RGB
    
    init(r: Float, g: Float, b: Float, a: Float) {
        self.a = a
        self.rgb = RGB(r: r, g: g, b: b)
    }
}

struct HSV {
    let h: Float // Angle in degrees [0,360] or -1 as Undefined
    let s: Float // Percent [0,1]
    let v: Float // Percent [0,1]
    
    static func rgb(h: Float, s: Float, v: Float) -> RGB {
        if s == 0 { return RGB(r: v, g: v, b: v) } // Achromatic grey
        
        let angle = (h >= 360 ? 0 : h)
        let sector = angle / 60 // Sector
        let i = floor(sector)
        let f = sector - i // Factorial part of h
        
        let p = v * (1 - s)
        let q = v * (1 - (s * f))
        let t = v * (1 - (s * (1 - f)))
        
        switch(i) {
        case 0:
            return RGB(r: v, g: t, b: p)
        case 1:
            return RGB(r: q, g: v, b: p)
        case 2:
            return RGB(r: p, g: v, b: t)
        case 3:
            return RGB(r: p, g: q, b: v)
        case 4:
            return RGB(r: t, g: p, b: v)
        default:
            return RGB(r: v, g: p, b: q)
        }
    }
    
    static func rgb(hsv: HSV) -> RGB {
        return rgb(h: hsv.h, s: hsv.s, v: hsv.v)
    }
    
    var rgb: RGB {
        return HSV.rgb(hsv: self)
    }
    
    /// Returns a normalized point with x=h and y=v
    var point: CGPoint {
        return CGPoint(x: CGFloat(h/360), y: CGFloat(v))
    }
    
    var PrintableString: String {
        return "H: \(self.h) S: \(self.s) V: \(self.v)"
    }
}


