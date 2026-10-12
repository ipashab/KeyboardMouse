import Foundation
import CoreGraphics

/// Виртуальные коды клавиш (Carbon virtual key codes).
public enum VK {
    public static let a = 0x00
    public static let s = 0x01
    public static let d = 0x02
    public static let f = 0x03
    public static let h = 0x04
    public static let g = 0x05
    public static let z = 0x06
    public static let x = 0x07
    public static let c = 0x08
    public static let v = 0x09
    public static let b = 0x0B
    public static let q = 0x0C
    public static let w = 0x0D
    public static let e = 0x0E
    public static let r = 0x0F
    public static let y = 0x10
    public static let t = 0x11
    public static let one = 0x12
    public static let two = 0x13
    public static let three = 0x14
    public static let four = 0x15
    public static let six = 0x16
    public static let five = 0x17
    public static let equal = 0x18
    public static let nine = 0x19
    public static let seven = 0x1A
    public static let minus = 0x1B
    public static let eight = 0x1C
    public static let zero = 0x1D
    public static let rightBracket = 0x1E
    public static let o = 0x1F
    public static let u = 0x20
    public static let leftBracket = 0x21
    public static let i = 0x22
    public static let p = 0x23
    public static let returnKey = 0x24
    public static let l = 0x25
    public static let j = 0x26
    public static let quote = 0x27
    public static let k = 0x28
    public static let semicolon = 0x29
    public static let backslash = 0x2A
    public static let comma = 0x2B
    public static let slash = 0x2C
    public static let n = 0x2D
    public static let m = 0x2E
    public static let period = 0x2F
    public static let tab = 0x30
    public static let space = 0x31
    public static let grave = 0x32
    public static let delete = 0x33
    public static let escape = 0x35
    public static let command = 0x37
    public static let shift = 0x38
    public static let capsLock = 0x39
    public static let option = 0x3A
    public static let control = 0x3B
    public static let rightCommand = 0x36
    public static let rightShift = 0x3C
    public static let rightOption = 0x3D
    public static let rightControl = 0x3E
    public static let function = 0x3F
    public static let f17 = 0x40
    public static let keypadDecimal = 0x41
    public static let keypadMultiply = 0x43
    public static let keypadPlus = 0x45
    public static let keypadClear = 0x47
    public static let keypadDivide = 0x4B
    public static let keypadEnter = 0x4C
    public static let keypadMinus = 0x4E
    public static let keypadEquals = 0x51
    public static let keypad0 = 0x52
    public static let keypad1 = 0x53
    public static let keypad2 = 0x54
    public static let keypad3 = 0x55
    public static let keypad4 = 0x56
    public static let keypad5 = 0x57
    public static let keypad6 = 0x58
    public static let keypad7 = 0x59
    public static let keypad8 = 0x5B
    public static let keypad9 = 0x5C
    public static let f5 = 0x60
    public static let f6 = 0x61
    public static let f7 = 0x62
    public static let f3 = 0x63
    public static let f8 = 0x64
    public static let f9 = 0x65
    public static let f11 = 0x67
    public static let f13 = 0x69
    public static let f16 = 0x6A
    public static let f14 = 0x6B
    public static let f10 = 0x6D
    public static let f12 = 0x6F
    public static let f15 = 0x71
    public static let help = 0x72
    public static let home = 0x73
    public static let pageUp = 0x74
    public static let deleteForward = 0x75
    public static let f4 = 0x76
    public static let end = 0x77
    public static let f2 = 0x78
    public static let pageDown = 0x79
    public static let f1 = 0x7A
    public static let leftArrow = 0x7B
    public static let rightArrow = 0x7C
    public static let downArrow = 0x7D
    public static let upArrow = 0x7E

    /// Коды, являющиеся чистыми модификаторами (для рекордера).
    public static let modifierCodes: Set<Int> = [
        command, shift, capsLock, option, control,
        rightCommand, rightShift, rightOption, rightControl, function,
    ]
}

private let keyNames: [Int: String] = [
    VK.a: "A", VK.s: "S", VK.d: "D", VK.f: "F", VK.h: "H", VK.g: "G",
    VK.z: "Z", VK.x: "X", VK.c: "C", VK.v: "V", VK.b: "B", VK.q: "Q",
    VK.w: "W", VK.e: "E", VK.r: "R", VK.y: "Y", VK.t: "T", VK.o: "O",
    VK.u: "U", VK.i: "I", VK.p: "P", VK.l: "L", VK.j: "J", VK.k: "K",
    VK.n: "N", VK.m: "M",
    VK.one: "1", VK.two: "2", VK.three: "3", VK.four: "4", VK.five: "5",
    VK.six: "6", VK.seven: "7", VK.eight: "8", VK.nine: "9", VK.zero: "0",
    VK.equal: "=", VK.minus: "-", VK.rightBracket: "]", VK.leftBracket: "[",
    VK.quote: "'", VK.semicolon: ";", VK.backslash: "\\", VK.comma: ",",
    VK.slash: "/", VK.period: ".", VK.grave: "`",
    VK.returnKey: "Enter", VK.tab: "Tab",
    VK.space: "Пробел", VK.delete: "Delete", VK.escape: "Esc",
    VK.capsLock: "Caps Lock", VK.help: "Help", VK.home: "Home", VK.end: "End",
    VK.pageUp: "Page Up", VK.pageDown: "Page Down",
    VK.leftArrow: "←", VK.rightArrow: "→", VK.downArrow: "↓", VK.upArrow: "↑",
    VK.f1: "F1", VK.f2: "F2", VK.f3: "F3", VK.f4: "F4", VK.f5: "F5",
    VK.f6: "F6", VK.f7: "F7", VK.f8: "F8", VK.f9: "F9", VK.f10: "F10",
    VK.f11: "F11", VK.f12: "F12", VK.f13: "F13", VK.f14: "F14",
    VK.f15: "F15", VK.f16: "F16", VK.f17: "F17",
]

/// Человекочитаемое имя клавиши по её коду.
public func keyName(_ keyCode: Int) -> String {
    guard keyCode != 0 else { return "" }
    return keyNames[keyCode] ?? "Код \(keyCode)"
}

/// Отображение комбинации модификаторов в символы.
private func modifierSymbols(_ flags: CGEventFlags) -> String {
    var s = ""
    if flags.contains(.maskControl) { s += "⌃" }
    if flags.contains(.maskAlternate) { s += "⌥" }
    if flags.contains(.maskShift) { s += "⇧" }
    if flags.contains(.maskCommand) { s += "⌘" }
    return s
}

/// Строка вида "⇧⌥ M" для отображения хоткея.
public func hotkeyLabel(keyCode: Int, modifiers: Int) -> String {
    let mods = modifierSymbols(CGEventFlags(rawValue: UInt64(bitPattern: Int64(modifiers))))
    let name = keyName(keyCode)
    if mods.isEmpty { return name }
    return "\(mods) \(name)"
}
