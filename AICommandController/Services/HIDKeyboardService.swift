import Foundation
import IOKit.hid
import IOKit.hidsystem

struct HIDKeyboardDevice {
    var descriptor: InputDeviceDescriptor
    var usageToControl: [UInt32: ControllerControl]
}

@MainActor
final class HIDKeyboardService {
    var onDevicesChanged: (([HIDKeyboardDevice]) -> Void)?
    var onKeyChanged: ((String, ControllerControl, Bool) -> Void)?

    private let manager: IOHIDManager
    private var devices: [UInt: HIDKeyboardDevice] = [:]
    private var started = false
    private let assignmentsKey = "hidKeyboardAssignments.v1"
    private var savedAssignments: [String: [String: String]]

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        savedAssignments = UserDefaults.standard.dictionary(forKey: assignmentsKey) as? [String: [String: String]] ?? [:]
    }

    var inputMonitoringGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func start() {
        guard !started else { return }
        started = true
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
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
        devices.removeAll()
        started = false
    }

    fileprivate func deviceMatched(_ device: IOHIDDevice) {
        if (IOHIDDeviceGetProperty(device, kIOHIDBuiltInKey as CFString) as? NSNumber)?.boolValue == true {
            return
        }
        let key = pointerKey(device)
        let vendorID = intProperty(device, key: kIOHIDVendorIDKey)
        let productID = intProperty(device, key: kIOHIDProductIDKey)
        let locationID = intProperty(device, key: kIOHIDLocationIDKey)
        let serial = stringProperty(device, key: kIOHIDSerialNumberKey)
        let product = stringProperty(device, key: kIOHIDProductKey)
        let manufacturer = stringProperty(device, key: kIOHIDManufacturerKey)
        let name = product ?? manufacturer ?? "外接键盘"
        let stablePart = serial ?? String(locationID)
        let deviceID = "hid-keyboard.\(vendorID).\(productID).\(stablePart)"

        var usageToControl: [UInt32: ControllerControl] = [:]
        var labels: [ControllerControl: String] = [:]
        for (usageString, controlString) in savedAssignments[deviceID] ?? [:] {
            guard let usage = UInt32(usageString),
                  let control = ControllerControl(rawValue: controlString),
                  ControllerControl.hidControls.contains(control)
            else { continue }
            usageToControl[usage] = control
            labels[control] = "\(control.rawValue) · \(Self.keyName(usage))"
        }
        let descriptor = InputDeviceDescriptor(
            id: deviceID,
            name: name,
            kind: .hidKeyboard,
            connected: true,
            controls: ControllerControl.hidControls,
            controlLabels: labels
        )
        devices[key] = HIDKeyboardDevice(descriptor: descriptor, usageToControl: usageToControl)
        publishDevices()
    }

    fileprivate func deviceRemoved(_ device: IOHIDDevice) {
        devices.removeValue(forKey: pointerKey(device))
        publishDevices()
    }

    fileprivate func inputValueChanged(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        let deviceKey = pointerKey(device)
        let usage = IOHIDElementGetUsage(element)
        guard IOHIDElementGetUsagePage(element) == kHIDPage_KeyboardOrKeypad,
              usage >= 4, usage <= 231,
              var info = devices[deviceKey]
        else { return }

        let control: ControllerControl
        if let existing = info.usageToControl[usage] {
            control = existing
        } else {
            let used = Set(info.usageToControl.values)
            guard let available = ControllerControl.hidControls.first(where: { !used.contains($0) }) else { return }
            control = available
            info.usageToControl[usage] = control
            info.descriptor.controlLabels[control] = "\(control.rawValue) · \(Self.keyName(usage))"
            devices[deviceKey] = info
            var assignments = savedAssignments[info.descriptor.id] ?? [:]
            assignments[String(usage)] = control.rawValue
            savedAssignments[info.descriptor.id] = assignments
            UserDefaults.standard.set(savedAssignments, forKey: assignmentsKey)
            publishDevices()
        }
        onKeyChanged?(info.descriptor.id, control, IOHIDValueGetIntegerValue(value) != 0)
    }

    private func publishDevices() {
        onDevicesChanged?(devices.values.sorted { $0.descriptor.name < $1.descriptor.name })
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

    private static func keyName(_ usage: UInt32) -> String {
        if usage >= 4, usage <= 29 {
            return String(UnicodeScalar(65 + usage - 4)!)
        }
        if usage >= 30, usage <= 38 { return String(usage - 29) }
        if usage == 39 { return "0" }
        let names: [UInt32: String] = [
            40: "Return", 41: "Esc", 42: "Delete", 43: "Tab", 44: "Space",
            79: "→", 80: "←", 81: "↓", 82: "↑"
        ]
        return names[usage] ?? "HID \(usage)"
    }
}

private func hidDeviceMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let service = Unmanaged<HIDKeyboardService>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in service.deviceMatched(device) }
}

private func hidDeviceRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let service = Unmanaged<HIDKeyboardService>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in service.deviceRemoved(device) }
}

private func hidInputValueChanged(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard let context else { return }
    let service = Unmanaged<HIDKeyboardService>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in service.inputValueChanged(value) }
}
