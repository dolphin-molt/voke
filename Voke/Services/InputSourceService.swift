import Carbon
import Foundation

final class InputSourceService {
    func toggleChineseEnglish() -> String? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        let currentLanguages = stringArrayProperty(current, key: kTISPropertyInputSourceLanguages)
        let currentlyChinese = currentLanguages.contains { $0.lowercased().hasPrefix("zh") }
        let sources = (TISCreateInputSourceList(nil, false).takeRetainedValue() as NSArray)
            .compactMap { $0 as! TISInputSource? }
            .filter(isSelectableKeyboardSource)

        let preferredPrefix = currentlyChinese ? "en" : "zh"
        let target = sources.first { source in
            stringArrayProperty(source, key: kTISPropertyInputSourceLanguages)
                .contains { $0.lowercased().hasPrefix(preferredPrefix) }
        }

        guard let target, TISSelectInputSource(target) == noErr else { return nil }
        return displayName(target)
    }

    private func isSelectableKeyboardSource(_ source: TISInputSource) -> Bool {
        let category = stringProperty(source, key: kTISPropertyInputSourceCategory)
        let enabled = boolProperty(source, key: kTISPropertyInputSourceIsEnabled)
        let selectable = boolProperty(source, key: kTISPropertyInputSourceIsSelectCapable)
        return category == (kTISCategoryKeyboardInputSource as String) && enabled && selectable
    }

    private func displayName(_ source: TISInputSource) -> String {
        stringProperty(source, key: kTISPropertyLocalizedName)
            ?? stringProperty(source, key: kTISPropertyInputSourceID)
            ?? "输入源"
    }

    private func stringProperty(_ source: TISInputSource, key: CFString) -> String? {
        property(source, key: key) as? String
    }

    private func stringArrayProperty(_ source: TISInputSource, key: CFString) -> [String] {
        property(source, key: key) as? [String] ?? []
    }

    private func boolProperty(_ source: TISInputSource, key: CFString) -> Bool {
        property(source, key: key) as? Bool ?? false
    }

    private func property(_ source: TISInputSource, key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }
}
