import AppKit
import CoreGraphics
import Testing
@testable import KeyboardMouse

// MARK: - Настройки

@Suite struct StoredSettingsTests {
    @Test func defaultsContainExpectedAssignments() {
        let s = StoredSettings.defaults()
        #expect(s.moveLeft == VK.leftArrow)
        #expect(s.moveRight == VK.rightArrow)
        #expect(s.moveUp == VK.upArrow)
        #expect(s.moveDown == VK.downArrow)
        #expect(s.clickLeft == VK.space)
        #expect(s.clickRight == VK.x)
        #expect(s.scrollUp == VK.e)
        #expect(s.scrollDown == VK.q)
        // Модификаторы хоткея: ровно Alt+Shift, без лишних бит.
        let required = CGEventFlags(rawValue: UInt64(bitPattern: s.toggleHotkey.modifiers))
        #expect(required == [.maskAlternate, .maskShift])
    }

    @Test func codableRoundTrip() throws {
        var original = StoredSettings.defaults()
        original.moveLeft = VK.h
        original.moveBaseSpeed = 17
        original.invertScroll = true
        original.fastModifier = .command
        original.toggleHotkey = HotKey(
            keyCode: VK.f5,
            modifiers: Int64(bitPattern: StoredSettings.modifierMask([.maskControl]).rawValue)
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(StoredSettings.self, from: data)
        #expect(original == restored)
    }
}

// MARK: - Классификация клавиш

@Suite struct KeyClassificationTests {
    private let settings = StoredSettings.defaults()

    @Test func toggleHotkeyMatch() {
        let flags: CGEventFlags = [.maskAlternate, .maskShift]
        #expect(settings.isToggle(VK.m, flags))
        // Лишний модификатор — не совпадение.
        #expect(!settings.isToggle(VK.m, flags.union(.maskCommand)))
        // Другая клавиша — не совпадение.
        #expect(!settings.isToggle(VK.n, flags))
        // Мусорные низкие (device-dependent) биты фильтруются маской.
        let deviceDependent = CGEventFlags(rawValue: 0xFF)
        #expect(!settings.isToggle(VK.m, deviceDependent))
    }

    @Test func movementClassification() {
        #expect(settings.moveDir(VK.leftArrow) == .left)
        #expect(settings.moveDir(VK.rightArrow) == .right)
        #expect(settings.moveDir(VK.upArrow) == .up)
        #expect(settings.moveDir(VK.downArrow) == .down)
        #expect(settings.moveDir(VK.a) == nil)
        #expect(settings.oneShotAction(VK.e) == nil)
        // Нулевой код — «не назначено».
        var s = settings
        s.moveLeft = 0
        #expect(s.moveDir(0) == nil)
    }

    @Test func scrollAndActionClassification() {
        #expect(settings.scrollDir(VK.e) == .up)
        #expect(settings.scrollDir(VK.q) == .down)
        #expect(settings.scrollDir(VK.space) == nil)

        #expect(settings.oneShotAction(VK.space) == .leftClick)
        #expect(settings.oneShotAction(VK.x) == .rightClick)
        #expect(settings.oneShotAction(VK.c) == .middleClick)
        #expect(settings.oneShotAction(VK.d) == .doubleClick)
        #expect(settings.oneShotAction(VK.g) == .dragToggle)
        #expect(settings.oneShotAction(VK.e) == nil)
        #expect(settings.oneShotAction(0) == nil)
    }

    @Test func speedRamp() {
        #expect(settings.movementSpeed(held: 0, fast: false) == settings.moveBaseSpeed)
        #expect(settings.movementSpeed(held: .infinity, fast: false) == settings.moveMaxSpeed)
        #expect(abs(
            settings.movementSpeed(held: .infinity, fast: true)
                - settings.moveMaxSpeed * settings.fastMultiplier
        ) < 0.001)

        var flat = settings
        flat.accelerationEnabled = false
        #expect(flat.movementSpeed(held: 10, fast: false) == flat.moveBaseSpeed)

        #expect(settings.scrollSpeed(held: 0) == settings.scrollBaseSpeed)
        #expect(settings.scrollSpeed(held: .infinity) == settings.scrollMaxSpeed)
    }
}

// MARK: - Отображение клавиш

@Suite struct KeyPresentationTests {
    @Test func keyNames() {
        #expect(keyName(VK.leftArrow) == "←")
        #expect(keyName(VK.space) == "Пробел")
        #expect(keyName(VK.escape) == "Esc")
        #expect(keyName(0) == "")
        #expect(keyName(9999) == "Код 9999")
    }

    @Test func hotkeyLabel() {
        let label = KeyboardMouse.hotkeyLabel(
            keyCode: VK.m,
            modifiers: Int(StoredSettings.modifierMask([.maskAlternate, .maskShift]).rawValue)
        )
        #expect(label == "⌥⇧ M")
    }

    @Test func nsEventAndCGEventFlagsShareDomain() {
        // Домены device-independent модификаторов NSEvent и CGEventFlags
        // обязаны совпадать — на этом держится захват хоткея в рекордере.
        #expect(
            CGEventFlags.maskShift.rawValue
                == UInt64(NSEvent.ModifierFlags.shift.rawValue)
        )
        #expect(
            CGEventFlags.maskAlternate.rawValue
                == UInt64(NSEvent.ModifierFlags.option.rawValue)
        )
        #expect(
            CGEventFlags.maskCommand.rawValue
                == UInt64(NSEvent.ModifierFlags.command.rawValue)
        )
        #expect(
            CGEventFlags.maskControl.rawValue
                == UInt64(NSEvent.ModifierFlags.control.rawValue)
        )
    }
}

// MARK: - Легенда оверлея

@Suite struct OverlayLegendTests {
    @Test func legendReflectsAssignments() {
        var s = StoredSettings.defaults()
        let full = ModeOverlayPanel.legendLines(s)
        #expect(full.contains("Esc — выход"))
        #expect(full.contains { $0.contains("движение") })
        #expect(full.contains { $0.contains("клик") })
        #expect(full.contains { $0.contains("прокрутка") })

        // Снятые назначения исчезают из легенды.
        s.clickMiddle = 0
        let partial = ModeOverlayPanel.legendLines(s)
        #expect(!partial.contains { $0.contains("средний клик") })
    }
}
