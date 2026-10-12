import Foundation
import CoreGraphics

/// Направление движения курсора или прокрутки.
public enum Direction: CaseIterable, Hashable {
    case left, right, up, down
}

/// Одномоментное действие по нажатию клавиши.
public enum OneShotAction: Equatable {
    case leftClick, rightClick, middleClick, doubleClick, dragToggle
}

/// Выбор «ускоряющего» модификатора.
public enum FastModifier: String, Codable, CaseIterable, Equatable {
    case none
    case shift
    case control
    case option
    case command

    public var label: String {
        switch self {
        case .none: return "Нет"
        case .shift: return "⇧ Shift"
        case .control: return "⌃ Control"
        case .option: return "⌥ Option"
        case .command: return "⌘ Command"
        }
    }
}

/// Глобальный хоткей (код клавиши + маска модификаторов).
public struct HotKey: Codable, Equatable {
    public var keyCode: Int
    /// Сырое значение CGEventFlags, ограниченное четырьмя модификаторами.
    public var modifiers: Int64

    public init(keyCode: Int, modifiers: Int64) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// Все настройки приложения.
public struct StoredSettings: Codable, Equatable {
    public var toggleHotkey: HotKey
    public var moveLeft: Int
    public var moveRight: Int
    public var moveUp: Int
    public var moveDown: Int
    public var clickLeft: Int
    public var clickRight: Int
    public var clickMiddle: Int
    public var clickDouble: Int
    public var dragToggle: Int
    public var scrollUp: Int
    public var scrollDown: Int
    public var moveBaseSpeed: Double
    public var moveMaxSpeed: Double
    public var accelTime: Double
    public var accelerationEnabled: Bool
    public var fastModifier: FastModifier
    public var fastMultiplier: Double
    public var scrollBaseSpeed: Double
    public var scrollMaxSpeed: Double
    public var scrollAccelTime: Double
    public var invertScroll: Bool

    public static func `defaults`() -> StoredSettings {
        var s = StoredSettings(
            toggleHotkey: HotKey(keyCode: VK.m, modifiers: 0),
            moveLeft: VK.leftArrow,
            moveRight: VK.rightArrow,
            moveUp: VK.upArrow,
            moveDown: VK.downArrow,
            clickLeft: VK.space,
            clickRight: VK.x,
            clickMiddle: VK.c,
            clickDouble: VK.d,
            dragToggle: VK.g,
            scrollUp: VK.e,
            scrollDown: VK.q,
            moveBaseSpeed: 5,
            moveMaxSpeed: 80,
            accelTime: 1.2,
            accelerationEnabled: true,
            fastModifier: .shift,
            fastMultiplier: 3,
            scrollBaseSpeed: 30,
            scrollMaxSpeed: 150,
            scrollAccelTime: 1.0,
            invertScroll: false
        )
        s.toggleHotkey.modifiers = Int64(
            StoredSettings.modifierMask([.maskAlternate, .maskShift]).rawValue
        )
        return s
    }

    /// Маска интересующих нас модификаторов.
    public static var interestingModifiers: CGEventFlags {
        [.maskShift, .maskControl, .maskAlternate, .maskCommand]
    }

    /// Оставить только четыре основных модификатора в флагах.
    public static func modifierMask(_ flags: CGEventFlags) -> CGEventFlags {
        flags.intersection(interestingModifiers)
    }

    // MARK: - Классификация клавиш

    /// Является ли нажатие глобальным хоткеем переключения режима.
    public func isToggle(_ keyCode: Int, _ flags: CGEventFlags) -> Bool {
        guard keyCode == toggleHotkey.keyCode else { return false }
        let pressed = StoredSettings.modifierMask(flags)
        let required = CGEventFlags(rawValue: UInt64(bitPattern: toggleHotkey.modifiers))
        return pressed == required
    }

    /// Направление движения, назначенное клавише (nil — клавиша не назначена).
    public func moveDir(_ keyCode: Int) -> Direction? {
        switch keyCode {
        case moveLeft where moveLeft != 0: return .left
        case moveRight where moveRight != 0: return .right
        case moveUp where moveUp != 0: return .up
        case moveDown where moveDown != 0: return .down
        default: return nil
        }
    }

    /// Направление прокрутки, назначенное клавише.
    public func scrollDir(_ keyCode: Int) -> Direction? {
        switch keyCode {
        case scrollUp where scrollUp != 0: return .up
        case scrollDown where scrollDown != 0: return .down
        default: return nil
        }
    }

    /// Одномоментное действие, назначенное клавише.
    public func oneShotAction(_ keyCode: Int) -> OneShotAction? {
        if keyCode != 0 && keyCode == clickLeft { return .leftClick }
        if keyCode != 0 && keyCode == clickRight { return .rightClick }
        if keyCode != 0 && keyCode == clickMiddle { return .middleClick }
        if keyCode != 0 && keyCode == clickDouble { return .doubleClick }
        if keyCode != 0 && keyCode == dragToggle { return .dragToggle }
        return nil
    }

    /// Любая ли из назначенных в режиме клавиш нажата.
    public func isControlKey(_ keyCode: Int) -> Bool {
        moveDir(keyCode) != nil || scrollDir(keyCode) != nil
            || oneShotAction(keyCode) != nil
    }

    /// Ускоряющий модификатор сейчас зажат?
    public func fastModifierActive(_ flags: CGEventFlags) -> Bool {
        switch fastModifier {
        case .none: return false
        case .shift: return flags.contains(.maskShift)
        case .control: return flags.contains(.maskControl)
        case .option: return flags.contains(.maskAlternate)
        case .command: return flags.contains(.maskCommand)
        }
    }

    /// Скорость движения (px за тик) после удержания направления в течение `seconds`.
    public func movementSpeed(held seconds: Double, fast: Bool) -> Double {
        var speed = moveBaseSpeed
        if accelerationEnabled {
            let t = accelTime > 0 ? min(1, seconds / accelTime) : 1
            speed = moveBaseSpeed + (moveMaxSpeed - moveBaseSpeed) * t
        }
        if fast { speed *= fastMultiplier }
        return speed
    }

    /// Скорость прокрутки (px за тик) после удержания в течение `seconds`.
    public func scrollSpeed(held seconds: Double) -> Double {
        guard scrollAccelTime > 0 else { return scrollMaxSpeed }
        let t = min(1, seconds / scrollAccelTime)
        return scrollBaseSpeed + (scrollMaxSpeed - scrollBaseSpeed) * t
    }
}
