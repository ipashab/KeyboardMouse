import SwiftUI
import AppKit

/// Содержимое окна настроек.
struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    /// Обратный вызов «открыть системные настройки Accessibility».
    let openAccessibility: () -> Void
    /// Обратный вызов «перезапустить приложение».
    let relaunch: () -> Void
    /// Текущее состояние контроллера (tap установлен?).
    let isRunning: () -> Bool

    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var controllerRunning: Bool = false

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !accessibilityGranted {
                    permissionBanner
                } else if !controllerRunning {
                    restartBanner
                }

                GroupBox("Переключение режима") {
                    hotkeySection
                }

                GroupBox("Движение курсора") {
                    movementSection
                }

                GroupBox("Клики и перетаскивание") {
                    clicksSection
                }

                GroupBox("Прокрутка") {
                    scrollSection
                }

                GroupBox("Скорость") {
                    speedSection
                }

                HStack {
                    Spacer()
                    Button("Сбросить настройки") { store.resetToDefaults() }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 520, height: 700)
        .onReceive(timer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
            controllerRunning = isRunning()
        }
    }

    // MARK: - Баннеры

    /// Права есть, но текущий процесс их ещё не подхватил.
    private var restartBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                "Разрешение получено. Чтобы оно вступило в силу, перезапустите приложение.",
                systemImage: "arrow.triangle.2.circlepath"
            )
            .foregroundStyle(.blue)
            .font(.callout)
            Button("Перезапустить приложение") { relaunch() }
        }
        .padding(12)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                "Приложению нужен доступ «Управление компьютером» (Accessibility), "
                    + "иначе перехват клавиш и управление курсором не работают.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
            .font(.callout)
            HStack {
                Button("Открыть системные настройки") { openAccessibility() }
                Text("Включите переключатель, затем при необходимости перезапустите приложение.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Секции

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Хоткей входа в режим").frame(width: 180, alignment: .leading)
                recorder(
                    title: hotkeyLabel(
                        keyCode: store.settings.toggleHotkey.keyCode,
                        modifiers: Int(store.settings.toggleHotkey.modifiers)
                    ),
                    capturesHotkey: true
                ) { keyCode, mods in
                    store.settings.toggleHotkey = HotKey(keyCode: keyCode, modifiers: mods)
                }
                Spacer()
            }
            Text("Нажатие хоткея снова — выход. Esc внутри режима тоже выходит.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var movementSection: some View {
        VStack(spacing: 6) {
            keyRow("Влево", binding: $store.settings.moveLeft)
            keyRow("Вправо", binding: $store.settings.moveRight)
            keyRow("Вверх", binding: $store.settings.moveUp)
            keyRow("Вниз", binding: $store.settings.moveDown)
        }
        .padding(.vertical, 4)
    }

    private var clicksSection: some View {
        VStack(spacing: 6) {
            keyRow("Клик левой кнопкой", binding: $store.settings.clickLeft)
            keyRow("Правый клик", binding: $store.settings.clickRight)
            keyRow("Средний клик", binding: $store.settings.clickMiddle)
            keyRow("Двойной клик", binding: $store.settings.clickDouble)
            keyRow("Перетаскивание (вкл/выкл)", binding: $store.settings.dragToggle)
        }
        .padding(.vertical, 4)
    }

    private var scrollSection: some View {
        VStack(spacing: 6) {
            keyRow("Прокрутка вверх", binding: $store.settings.scrollUp)
            keyRow("Прокрутка вниз", binding: $store.settings.scrollDown)
            Toggle("Инвертировать прокрутку", isOn: $store.settings.invertScroll)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private var speedSection: some View {
        VStack(spacing: 10) {
            slider("Базовая скорость (px/тик)", value: $store.settings.moveBaseSpeed,
                   range: 1...50, format: "%.0f")
            Toggle("Ускорение при удержании", isOn: $store.settings.accelerationEnabled)
            if store.settings.accelerationEnabled {
                slider("Максимальная скорость (px/тик)", value: $store.settings.moveMaxSpeed,
                       range: 10...300, format: "%.0f")
                slider("Время разгона (сек)", value: $store.settings.accelTime,
                       range: 0.2...3, format: "%.1f")
            }
            slider("Скорость прокрутки (px/тик)", value: $store.settings.scrollBaseSpeed,
                   range: 5...200, format: "%.0f")
            if store.settings.accelerationEnabled {
                slider("Максимум прокрутки (px/тик)", value: $store.settings.scrollMaxSpeed,
                       range: 20...800, format: "%.0f")
            }

            HStack {
                Picker("Ускоряющий модификатор", selection: $store.settings.fastModifier) {
                    ForEach(FastModifier.allCases, id: \.self) { mod in
                        Text(mod.label).tag(mod)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
                if store.settings.fastModifier != .none {
                    Slider(
                        value: $store.settings.fastMultiplier,
                        in: 1.5...8, step: 0.5
                    )
                    Text("×\(store.settings.fastMultiplier, format: .number)")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Вспомогательные построители

    private func keyRow(_ title: String, binding: Binding<Int>) -> some View {
        HStack {
            Text(title).frame(width: 190, alignment: .leading)
            recorder(
                title: binding.wrappedValue == 0 ? "" : keyName(binding.wrappedValue),
                capturesHotkey: false
            ) { keyCode, _ in
                binding.wrappedValue = keyCode
            }
            if binding.wrappedValue != 0 {
                Button {
                    binding.wrappedValue = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Снять назначение")
            }
            Spacer()
        }
    }

    private func recorder(
        title: String, capturesHotkey: Bool,
        onCapture: @escaping (Int, Int64) -> Void
    ) -> some View {
        KeyCaptureButton(
            title: title,
            capturesHotkey: capturesHotkey,
            onCapture: onCapture,
            onArmedChange: { _ in }
        )
        .frame(width: 130, height: 26)
    }

    private func slider(
        _ title: String, value: Binding<Double>, range: ClosedRange<Double>,
        format: String
    ) -> some View {
        HStack {
            Text(title).frame(width: 240, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}
