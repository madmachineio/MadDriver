import SwiftIO

#if canImport(MadDisplay)
import struct MadDisplay.ColorSpace
#endif

public final class MadST7789 {

    public enum Rotation {
        case angle0, angle90, angle180, angle270
    }

    private let initConfigs: [(address: Command, data: [UInt8]?)] = [
        (.COLMOD, [0x55]),
        (.INVON, nil),
        (.DISPON, nil)
    ]


/*
    private let initConfigs: [(address: Command, data: [UInt8]?)] = [
        (.COLMOD, [0x05]),

        (.PORCTRL, [0x0C, 0x0C, 0x00, 0x33, 0x33]),
        (.GCTRL, [0x35]),
        (.VCOMS, [0x32]),
        (.VDVVRHEN, [0x01]),
        (.VRHS, [0x15]),
        (.VDVSET, [0x20]),
        (.FRCTR2, [0x0F]),
        (.PWCTRL1, [0xA4, 0xA1]),
        (.PVGAMCTRL, [0xD0, 0x04, 0x0A, 0x08, 0x07, 0x05, 0x32, 0x32, 0x48, 0x38, 0x15, 0x15, 0x2A, 0x2E]),
        (.NVGAMCTRL, [0xD0, 0x07, 0x0D, 0x09, 0x09, 0x16, 0x30, 0x44, 0x49, 0x39, 0x16, 0x16, 0x2B, 0x2F]),

        (.INVON, nil),
        (.DISPON, nil)
    ]
*/
	let spi: SPI
    let cs, dc, rst, bl: DigitalOut

    private(set) var rotation: Rotation 
    
    public private(set) var width: Int
    public private(set) var height: Int
    public let bitCount = 16

#if canImport(MadDisplay)
    public var colorSpace = ColorSpace()
#endif


    private var xOffset: Int
    private var yOffset: Int

    public init(spi: SPI, cs: DigitalOut, dc: DigitalOut, rst: DigitalOut, bl: DigitalOut,
                width: Int = 240, height: Int = 240, rotation: Rotation = .angle0) {
        guard (width == 240 && height == 240) || (width == 240 && height == 320) ||
              (width == 320 && height == 240) else {
                  fatalError("Not support this resolution!")
              }
        
        self.spi = spi
        self.cs = cs
        self.dc = dc
        self.rst = rst
        self.bl = bl
        self.width = width
        self.height = height
        self.rotation = rotation
        self.xOffset = 0
        self.yOffset = 0

#if canImport(MadDisplay)
        colorSpace.depth = 16
        colorSpace.grayscale = false
        colorSpace.reverseBytesInWord = true
#endif

        reset()
        setRoation(rotation)

        initConfigs.forEach { config in
            writeConfig(config.data, to: config.address)
        }

        clearScreen()
        bl.high()
    }

    public func setRoation(_ angle: Rotation) {
        rotation = angle 
        var madctlConfig: MadctlConfig

        if width == 240 && height == 240 {
            switch rotation {
            case .angle0:
                xOffset = 0
                yOffset = 0
                madctlConfig = [.pageTopToBottom, .leftToRight, .normalMode, .lineTopToBottom, .RGB]
            case .angle90:
                xOffset = 0
                yOffset = 0
                madctlConfig = [.pageTopToBottom, .rightToLeft, .reverseMode, .lineTopToBottom, .RGB]
            case .angle180:
                xOffset = 0
                yOffset = 80
                madctlConfig = [.pageBottomToTop, .rightToLeft, .normalMode, .lineTopToBottom, .RGB]
            case .angle270:
                xOffset = 80
                yOffset = 0
                madctlConfig = [.pageBottomToTop, .leftToRight, .reverseMode, .lineTopToBottom, .RGB]
            }
        } else if width == 240 && height == 320 {
            xOffset = 0
            yOffset = 0
            switch rotation {
            case .angle0:
                madctlConfig = [.pageTopToBottom, .leftToRight, .normalMode, .lineTopToBottom, .RGB]
            case .angle90:
                swap(&width, &height)
                madctlConfig = [.pageTopToBottom, .rightToLeft, .reverseMode, .lineTopToBottom, .RGB]
            case .angle180:
                madctlConfig = [.pageBottomToTop, .rightToLeft, .normalMode, .lineTopToBottom, .RGB]
            case .angle270:
                swap(&width, &height)
                madctlConfig = [.pageBottomToTop, .leftToRight, .reverseMode, .lineTopToBottom, .RGB]
            }
        } else {
            xOffset = 0
            yOffset = 0
            switch rotation {
            case .angle0:
                madctlConfig = [.pageTopToBottom, .rightToLeft, .reverseMode, .lineTopToBottom, .RGB]
            case .angle90:
                swap(&width, &height)
                madctlConfig = [.pageBottomToTop, .rightToLeft, .normalMode, .lineTopToBottom, .RGB]
            case .angle180:
                madctlConfig = [.pageBottomToTop, .leftToRight, .reverseMode, .lineTopToBottom, .RGB]
            case .angle270:
                swap(&width, &height)
                madctlConfig = [.pageTopToBottom, .leftToRight, .normalMode, .lineTopToBottom, .RGB]
            }
        }

        writeConfig([madctlConfig.rawValue], to: .MADCTL)
    }

    @inline(__always)
    public func writePixel(x: Int, y: Int, color: UInt16) {
        setAddrWindow(x: x, y: y, width: 1, height: 1)
        writeData(color)
    }

    public func writeBitmap(x: Int, y: Int, width w: Int, height h: Int, data: [UInt8]) {
        setAddrWindow(x: x, y: y, width: w, height: h) 
        writeData(data)
    }

    public func writeScreen(_ data: [UInt8]) {
        guard data.count <= width * height * 2 else { return }
        setAddrWindow(x: 0, y: 0, width: width, height: height) 
        writeData(data)
    }

    public func clearScreen(_ color: UInt16 = 0x0000) {
        let highByte = UInt8(color >> 8)
        let lowByte = UInt8(color & 0xFF)

        var data = [UInt8](repeating: 0, count: width * height * 2)

        for i in 0..<width * height {
            let pos = i * 2
            data[pos] = highByte
            data[pos + 1] = lowByte
        }

        writeScreen(data)
    }

    public func reset() {
        cs.high()
        rst.low()
        sleep(ms: 20)
        rst.high()
        sleep(ms: 120)

        wakeUp()
        sleep(ms: 120)
    }

    public func setAddrWindow(x: Int, y: Int, width w: Int, height h: Int) {
        let xStartHigh = UInt8( (x + xOffset) >> 8 )
        let xStartLow  = UInt8( (x + xOffset) & 0xFF )
        let xEndHigh = UInt8( (x + w + xOffset - 1) >> 8 )
        let xEndLow = UInt8( (x + w + xOffset - 1) & 0xFF )

        let yStartHigh = UInt8( (y + yOffset) >> 8 )
        let yStartLow  = UInt8( (y + yOffset) & 0xFF )
        let yEndHigh = UInt8( (y + h + yOffset - 1) >> 8 )
        let yEndLow = UInt8( (y + h + yOffset - 1) & 0xFF )

        writeConfig([xStartHigh, xStartLow, xEndHigh, xEndLow], to: .CASET)
        writeConfig([yStartHigh, yStartLow, yEndHigh, yEndLow], to: .RASET)
        writeCommand(.RAMWR)
    }
}

extension MadST7789 {
    enum Command: UInt8 {
        case NOP        = 0x00
        case SWRESET    = 0x01
        case RDDID      = 0x04
        case RDDST      = 0x09

        case SLPIN      = 0x10
        case SLPOUT     = 0x11
        case PTLON      = 0x12
        case NORON      = 0x13

        case INVOFF     = 0x20
        case INVON      = 0x21
        case DISPOFF    = 0x28
        case DISPON     = 0x29
        case CASET      = 0x2A
        case RASET      = 0x2B
        case RAMWR      = 0x2C
        case RAMRD      = 0x2E

        case PTLAR      = 0x30
        case TEOFF      = 0x34
        case TEON       = 0x35
        case MADCTL     = 0x36
        case COLMOD     = 0x3A

        case RAMCTRL    = 0xB0
        case RGBCTRL    = 0xB1
        case PORCTRL    = 0xB2
        case FRCTRL1    = 0xB3
        case PARCTRL    = 0xB5
        case GCTRL      = 0xB7
        case GTADJ      = 0xB8
        case DGMEN      = 0xBA
        case VCOMS      = 0xBB
        case POWSAVE    = 0xBC
        case DLPOFFSAVE = 0xBD

        case LCMCTRL    = 0xC0
        case IDSET      = 0xC1
        case VDVVRHEN   = 0xC2
        case VRHS       = 0xC3
        case VDVSET     = 0xC4
        case VCMOFSET   = 0xC5
        case FRCTR2     = 0xC6
        case CABCCTRL   = 0xC7
        case REGSEL1    = 0xC8
        case REGSEL2    = 0xCA
        case PWMFRSEL   = 0xCC

        case PWCTRL1    = 0xD0
        case VAPVANEN   = 0xD2
        case CMD2EN     = 0xDF

        case PVGAMCTRL  = 0xE0
        case NVGAMCTRL  = 0xE1
    }

    struct MadctlConfig: OptionSet {
        let rawValue: UInt8
        
        static let pageTopToBottom = MadctlConfig([])
        static let pageBottomToTop = MadctlConfig(rawValue: 0x80)

        static let leftToRight = MadctlConfig([])
        static let rightToLeft = MadctlConfig(rawValue: 0x40)

        static let normalMode = MadctlConfig([])
        static let reverseMode = MadctlConfig(rawValue: 0x20)

        static let lineTopToBottom = MadctlConfig([])
        static let lineBottomToTop = MadctlConfig(rawValue: 0x10)
        
        static let RGB = MadctlConfig([])
        static let BGR = MadctlConfig(rawValue: 0x08)
    }


    func wakeUp() {
        writeCommand(.SLPOUT)
    }

    func writeConfig(_ data: [UInt8]?, to address: Command) {
        writeCommand(address)
        if let data = data {
            writeData(data)
        }
    }

    func writeCommand(_ command: Command) {
        dc.low()
        cs.low()
        spi.write(command.rawValue)
        cs.high()
    }

    func writeData(_ data: UInt16) {
        let array = [UInt8(data >> 8), UInt8(data & 0xFF)]
        dc.high()
        cs.low()
        spi.write(array)
        cs.high()
    }

    func writeData(_ data: [UInt8]) {
        dc.high()
        cs.low()
        spi.write(data)
        cs.high()
    }

}