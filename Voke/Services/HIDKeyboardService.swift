import Foundation
import CoreGraphics
import IOKit.hid
import IOKit.hidsystem

struct HIDInputDevice {
    var descriptor: InputDeviceDescriptor
}

private struct HIDInterfaceInfo {
    let physicalID: String
    let product: String?
    let manufacturer: String?
    let transport: String?
    let vendorID: Int
    let productID: Int
    var capabilities: Set<HIDCapability>
    var controls: Set<ControllerControl>
    var controlLabels: [ControllerControl: String]
    var declaredButtonCount: Int
    var hasRelativePointerAxes: Bool
}

@MainActor
final class HIDInputService {
    var onDevicesChanged: (([HIDInputDevice]) -> Void)?
    var onControlChanged: ((String, ControllerControl, Bool) -> Void)?

    private let manager: IOHIDManager
    private var interfaces: [UInt: HIDInterfaceInfo] = [:]
    private var started = false
    private let learnedControlsKey = "hidLearnedControls.v2"
    private var learnedControls: [String: [String]]

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        learnedControls = UserDefaults.standard.dictionary(forKey: learnedControlsKey) as? [String: [String]] ?? [:]
    }

    var inputMonitoringGranted: Bool {
        CGPreflightListenEventAccess()
            || IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        // Keep the HID request for older macOS versions and HID-specific TCC paths.
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func start() {
        guard !started else { return }
        started = true
        let keyboard: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ]
        let mouse: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, [keyboard, mouse] as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, hidDeviceMatched, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, hidDeviceRemoved, context)
        IOHIDManagerRegisterInputValueCallback(manager, hidInputValueChanged, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func stop() {
        guard started else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        interfaces.removeAll()
        started = false
    }

    fileprivate func deviceMatched(_ device: IOHIDDevice) {
        if (IOHIDDeviceGetProperty(device, kIOHIDBuiltInKey as CFString) as? NSNumber)?.boolValue == true {
            return
        }

        let vendorID = intProperty(device, key: kIOHIDVendorIDKey)
        let productID = intProperty(device, key: kIOHIDProductIDKey)
        let locationID = intProperty(device, key: kIOHIDLocationIDKey)
        let serial = clean(stringProperty(device, key: kIOHIDSerialNumberKey))
        let product = clean(stringProperty(device, key: kIOHIDProductKey))
        let manufacturer = clean(stringProperty(device, key: kIOHIDManufacturerKey))
        let transport = clean(stringProperty(device, key: kIOHIDTransportKey))
        let stablePart = serial ?? String(locationID)
        let physicalID = "hid.\(vendorID).\(productID).\(stablePart)"
        let capabilities = capabilities(for: device)
        let mouseControls = capabilities.contains(.mouse) ? declaredMouseButtons(for: device) : []
        let restoredControls = Set((learnedControls[physicalID] ?? []).compactMap(ControllerControl.init(rawValue:)))
        let controls = mouseControls.union(restoredControls)
        let labels = Dictionary(uniqueKeysWithValues: controls.map { ($0, Self.controlName($0)) })

        interfaces[pointerKey(device)] = HIDInterfaceInfo(
            physicalID: physicalID,
            product: product,
            manufacturer: manufacturer,
            transport: transport,
            vendorID: vendorID,
            productID: productID,
            capabilities: capabilities,
            controls: controls,
            controlLabels: labels,
            declaredButtonCount: mouseControls.count,
            hasRelativePointerAxes: capabilities.contains(.mouse) && hasRelativePointerAxes(for: device)
        )
        publishDevices()
    }

    fileprivate func deviceRemoved(_ device: IOHIDDevice) {
        interfaces.removeValue(forKey: pointerKey(device))
        publishDevices()
    }

    fileprivate func inputValueChanged(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        let deviceKey = pointerKey(device)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        guard var info = interfaces[deviceKey] else { return }

        let isKeyboardControl = usagePage == kHIDPage_KeyboardOrKeypad && usage >= 4 && usage <= 231
        let isMouseButton = info.capabilities.contains(.mouse)
            && usagePage == kHIDPage_Button && usage >= 1 && usage <= 32
        guard isKeyboardControl || isMouseButton else { return }

        let control = ControllerControl.hid(usagePage: usagePage, usage: usage)
        if info.controls.insert(control).inserted {
            info.controlLabels[control] = Self.controlName(control)
            interfaces[deviceKey] = info
            var stored = Set(learnedControls[info.physicalID] ?? [])
            stored.insert(control.rawValue)
            learnedControls[info.physicalID] = stored.sorted()
            UserDefaults.standard.set(learnedControls, forKey: learnedControlsKey)
            publishDevices()
        }
        onControlChanged?(info.physicalID, control, IOHIDValueGetIntegerValue(value) != 0)
    }

    private func publishDevices() {
        let grouped = Dictionary(grouping: interfaces.values, by: \HIDInterfaceInfo.physicalID)
        let devices = grouped.compactMap { physicalID, members -> HIDInputDevice? in
            guard let first = members.first else { return nil }
            let capabilities = members.reduce(into: Set<HIDCapability>()) { $0.formUnion($1.capabilities) }
            var controls = members.reduce(into: Set<ControllerControl>()) { $0.formUnion($1.controls) }
            var labels = members.reduce(into: [ControllerControl: String]()) { result, member in
                result.merge(member.controlLabels) { current, _ in current }
            }
            if !capabilities.contains(.mouse) {
                controls = Set(controls.filter { !Self.isMouseButton($0) })
                labels = labels.filter { controls.contains($0.key) }
            }
            let declaredMouseButtonCount = members.map(\.declaredButtonCount).max() ?? 0
            let hasRelativePointerAxes = members.contains(where: \.hasRelativePointerAxes)
            let kind = HIDDeviceClassifier.kind(
                product: first.product,
                capabilities: capabilities,
                declaredMouseButtonCount: declaredMouseButtonCount,
                hasRelativePointerAxes: hasRelativePointerAxes
            )
            let descriptor = InputDeviceDescriptor(
                id: physicalID,
                name: Self.displayName(product: first.product, manufacturer: first.manufacturer, kind: kind),
                kind: kind,
                connected: true,
                controls: controls.sorted { $0.rawValue < $1.rawValue },
                controlLabels: labels,
                manufacturer: first.manufacturer,
                product: first.product,
                transport: first.transport,
                vendorID: first.vendorID,
                productID: first.productID,
                capabilities: capabilities,
                declaredButtonCount: declaredMouseButtonCount
            )
            return HIDInputDevice(descriptor: descriptor)
        }
        onDevicesChanged?(devices.sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending })
    }

    private func capabilities(for device: IOHIDDevice) -> Set<HIDCapability> {
        var result: Set<HIDCapability> = []
        let primaryPage = UInt32(intProperty(device, key: kIOHIDPrimaryUsagePageKey))
        let primaryUsage = UInt32(intProperty(device, key: kIOHIDPrimaryUsageKey))
        addCapability(page: primaryPage, usage: primaryUsage, to: &result)

        if let pairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Any]] {
            for pair in pairs {
                let page = (pair[kIOHIDDeviceUsagePageKey] as? NSNumber)?.uint32Value ?? 0
                let usage = (pair[kIOHIDDeviceUsageKey] as? NSNumber)?.uint32Value ?? 0
                // Keyboard and mouse classification comes from the interface's
                // primary usage. UsagePairs can describe every collection in a
                // composite report and otherwise makes a keyboard look like a mouse.
                if page == kHIDPage_Consumer || page >= 0xFF00 {
                    addCapability(page: page, usage: usage, to: &result)
                }
            }
        }
        return result
    }

    private func addCapability(page: UInt32, usage: UInt32, to result: inout Set<HIDCapability>) {
        if page == kHIDPage_GenericDesktop, usage == kHIDUsage_GD_Keyboard { result.insert(.keyboard) }
        if page == kHIDPage_GenericDesktop, usage == kHIDUsage_GD_Mouse { result.insert(.mouse) }
        if page == kHIDPage_Consumer { result.insert(.consumerControls) }
        if page >= 0xFF00 { result.insert(.vendorDefined) }
    }

    private func declaredMouseButtons(for device: IOHIDDevice) -> Set<ControllerControl> {
        guard let elements = IOHIDDeviceCopyMatchingElements(
            device,
            nil,
            IOOptionBits(kIOHIDOptionsTypeNone)
        ) else { return [] }
        var controls: Set<ControllerControl> = []
        for index in 0..<CFArrayGetCount(elements) {
            let element: IOHIDElement = unsafeBitCast(
                CFArrayGetValueAtIndex(elements, index),
                to: IOHIDElement.self
            )
            guard IOHIDElementGetUsagePage(element) == kHIDPage_Button else { continue }
            let usage = IOHIDElementGetUsage(element)
            guard usage >= 1, usage <= 32 else { continue }
            controls.insert(.hid(usagePage: UInt32(kHIDPage_Button), usage: usage))
        }
        return controls
    }

    private func hasRelativePointerAxes(for device: IOHIDDevice) -> Bool {
        guard let elements = IOHIDDeviceCopyMatchingElements(
            device,
            nil,
            IOOptionBits(kIOHIDOptionsTypeNone)
        ) else { return false }
        for index in 0..<CFArrayGetCount(elements) {
            let element: IOHIDElement = unsafeBitCast(
                CFArrayGetValueAtIndex(elements, index),
                to: IOHIDElement.self
            )
            guard IOHIDElementGetUsagePage(element) == kHIDPage_GenericDesktop else { continue }
            let usage = IOHIDElementGetUsage(element)
            if (usage == kHIDUsage_GD_X || usage == kHIDUsage_GD_Y), IOHIDElementIsRelative(element) {
                return true
            }
        }
        return false
    }

    private static func displayName(product: String?, manufacturer: String?, kind: InputDeviceKind) -> String {
        if let product, !isGenericProductName(product) { return product }
        if let manufacturer { return "\(manufacturer) · \(kind.title)" }
        return "通用 USB \(kind.title)"
    }

    private static func isGenericProductName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["USB KEYBOARD", "USB MOUSE", "KEYBOARD", "MOUSE", "HID DEVICE"].contains(normalized)
    }

    private static func controlName(_ control: ControllerControl) -> String {
        guard case let .hid(usagePage, usage) = control else { return control.rawValue }
        if usagePage == kHIDPage_Button {
            return switch usage {
            case 1: "鼠标左键"
            case 2: "鼠标右键"
            case 3: "鼠标中键"
            default: "鼠标侧键 \(usage - 3)"
            }
        }
        return keyName(usage)
    }

    private static func isMouseButton(_ control: ControllerControl) -> Bool {
        guard case let .hid(usagePage, _) = control else { return false }
        return usagePage == kHIDPage_Button
    }

    private static func keyName(_ usage: UInt32) -> String {
        if usage >= 4, usage <= 29 { return String(UnicodeScalar(65 + usage - 4)!) }
        if usage >= 30, usage <= 38 { return String(usage - 29) }
        if usage == 39 { return "0" }
        let names: [UInt32: String] = [
            40: "Return", 41: "Esc", 42: "Delete", 43: "Tab", 44: "Space",
            58: "F1", 59: "F2", 60: "F3", 61: "F4", 62: "F5", 63: "F6",
            64: "F7", 65: "F8", 66: "F9", 67: "F10", 68: "F11", 69: "F12",
            79: "→", 80: "←", 81: "↓", 82: "↑",
            224: "左 Control", 225: "左 Shift", 226: "左 Option", 227: "左 Command",
            228: "右 Control", 229: "右 Shift", 230: "右 Option", 231: "右 Command"
        ]
        return names[usage] ?? "HID \(usage)"
    }

    private func pointerKey(_ device: IOHIDDevice) -> UInt {
        UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque())
    }

    private func intProperty(_ device: IOHIDDevice, key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
    }

    private func stringProperty(_ device: IOHIDDevice, key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private func clean(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

enum HIDDeviceClassifier {
    static func kind(
        product: String?,
        capabilities: Set<HIDCapability>,
        declaredMouseButtonCount: Int,
        hasRelativePointerAxes: Bool = false
    ) -> InputDeviceKind {
        let normalizedProduct = product?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""

        if normalizedProduct.contains("KEYBOARD") || normalizedProduct.contains("键盘") {
            return .hidKeyboard
        }
        if normalizedProduct.contains("MOUSE") || normalizedProduct.contains("鼠标") {
            return .hidMouse
        }
        if capabilities.contains(.keyboard), capabilities.contains(.mouse) {
            // Gaming mice commonly expose a keyboard interface for macro keys.
            // Real mouse buttons or relative X/Y axes are stronger signals.
            if declaredMouseButtonCount > 0 || hasRelativePointerAxes { return .hidMouse }
            let compositeHints = ["RECEIVER", "DONGLE", "COMBO", "COMPOSITE", "接收器", "套装"]
            if normalizedProduct.isEmpty
                || normalizedProduct == "HID DEVICE"
                || compositeHints.contains(where: normalizedProduct.contains) {
                return .hidComposite
            }
            // A named device with a real Mouse primary interface is most often a
            // mouse whose programmable buttons are exposed as keyboard events.
            return .hidMouse
        }
        if capabilities.contains(.mouse) { return .hidMouse }
        return .hidKeyboard
    }
}

private func hidDeviceMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let service = Unmanaged<HIDInputService>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in service.deviceMatched(device) }
}

private func hidDeviceRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let service = Unmanaged<HIDInputService>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in service.deviceRemoved(device) }
}

private func hidInputValueChanged(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard let context else { return }
    let service = Unmanaged<HIDInputService>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in service.inputValueChanged(value) }
}
