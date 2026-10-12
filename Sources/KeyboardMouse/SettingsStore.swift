import Foundation
import Combine

/// Хранилище настроек: UserDefaults + JSON, с уведомлением слушателей об изменениях.
public final class SettingsStore: ObservableObject {
    private static let storageKey = "keyboardmouse.settings.v1"

    @Published public var settings: StoredSettings {
        didSet { persist(); onChange?(settings) }
    }

    /// Слушатель изменений (контроллер режима).
    public var onChange: ((StoredSettings) -> Void)?

    public init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(StoredSettings.self, from: data) {
            settings = decoded
        } else {
            settings = StoredSettings.defaults()
        }
    }

    public func resetToDefaults() {
        settings = StoredSettings.defaults()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
