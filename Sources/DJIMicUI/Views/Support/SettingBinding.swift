import DJIMicProtocol
import SwiftUI

extension AppModel {
    /// Creates a binding that only forwards real user changes. Reading the
    /// current value at set time avoids a feedback loop with the optimistic
    /// snapshot update.
    func settingBinding<Value: Equatable>(
        get: @escaping () -> Value,
        setting: @escaping (Value) -> MicSetting
    ) -> Binding<Value> {
        Binding(
            get: { get() },
            set: { [weak self] newValue in
                guard newValue != get() else { return }
                self?.send(setting(newValue))
            }
        )
    }
}
