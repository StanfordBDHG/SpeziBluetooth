//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftUI


private struct ScanNearbyDevicesModifier<Scanner: BluetoothScanner>: ViewModifier {
    private let enabled: Bool
    private let scanner: Scanner
    private let state: Scanner.ScanningState

    @Environment(\.scenePhase)
    private var scenePhase
    @Environment(\.surroundingScanModifiers)
    private var surroundingModifiers

    @Environment(\.minimumRSSI)
    private var minimumRSSI
    @Environment(\.advertisementStaleInterval)
    private var advertisementStaleInterval

    @State private var modifierId = UUID()

    init(enabled: Bool, scanner: Scanner, state: Scanner.ScanningState) {
        self.enabled = enabled
        self.scanner = scanner
        self.state = state
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: onForeground)
            .onDisappear(perform: onBackground)
            .onChange(of: scenePhase) { previous, _ in
                if scenePhase == .background {
                    onBackground() // app switched into the background
                } else if previous == .background {
                    onForeground() // app got out of the background again
                }
                // we don't care about active <-> inactive transition (e.g., happens when pulling down notification center)
            }
            .onChange(of: enabled, initial: false) {
                if enabled {
                    onForeground()
                } else {
                    onBackground()
                }
            }
            .onChange(of: state, initial: false) {
                if enabled {
                    updateScanningState(enabled: enabled)
                }
            }
            .onChange(of: minimumRSSI) {
                if enabled {
                    updateScanningState(enabled: enabled)
                }
            }
            .onChange(of: advertisementStaleInterval) {
                if enabled {
                    updateScanningState(enabled: enabled)
                }
            }
            .onChange(of: surroundingModifiers.retrieveReducedScanningState(for: scanner)) { _, newValue in
                guard let newValue else {
                    return
                }
                Task {
                    await scanner.updateScanningState(newValue)
                }
            }
    }

    @MainActor
    private func onForeground() {
        if enabled {
            updateScanningState(enabled: true)
            Task {
                await scanner.scanNearbyDevices(state)
            }
        }
    }

    @MainActor
    private func onBackground() {
        updateScanningState(enabled: false)

        if surroundingModifiers.hasPersistentInterest(for: scanner) {
            return // don't stop scanning if a surrounding modifier is expecting a scan to continue
        }

        Task {
            await scanner.stopScanning()
        }
    }

    @MainActor
    private func updateScanningState(enabled: Bool) {
        let state = state.updateOptions(minimumRSSI: minimumRSSI, advertisementStaleInterval: advertisementStaleInterval)
        surroundingModifiers.setModifierScanningState(enabled: enabled, with: scanner, modifierId: modifierId, state: state)
    }
}


extension View {
    /// Scan for nearby Bluetooth devices with a custom bluetooth scanner.
    /// - Parameters:
    ///   - enabled: Flag indicating if nearby device scanning is enabled.
    ///   - scanner: The bluetooth scanner.
    ///   - state: The current scanning state passed to the bluetooth scanner. ``BluetoothScanner/updateScanningState(_:)`` will be called if the contents of
    ///     this parameter changes.
    /// - Returns: The modified view.
    @_spi(APISupport)
    public func scanNearbyDevices<Scanner: BluetoothScanner>(enabled: Bool, scanner: Scanner, state: Scanner.ScanningState) -> some View {
        modifier(ScanNearbyDevicesModifier(enabled: enabled, scanner: scanner, state: state))
    }

    /// Scan for nearby Bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``Discover`` declarations provided in the initializer.
    ///
    /// All discovered devices for a given type can be accessed through the ``Bluetooth/nearbyDevices(for:)`` method.
    /// The first connected device can be accessed through the
    /// [Environment(_:)](https://developer.apple.com/documentation/swiftui/environment/init(_:)-8slkf) in your SwiftUI view.
    ///
    /// Nearby device search is automatically paused when the view disappears or if the app enters background and
    /// is automatically started again when the view appears or the app enters the foreground again.
    /// Further, scanning is automatically started if Bluetooth is turned on by the user while the view was already presented.
    ///
    /// The auto connect feature allows you to automatically connect to a bluetooth peripheral if it is the only device
    /// discovered for a short period in time.
    ///
    /// - Tip: If you want to continuously search for auto-connectable device in the background,
    ///     you might want to use the ``SwiftUICore/View/autoConnect(enabled:with:minimumRSSI:advertisementStaleInterval:)`` modifier instead.
    ///
    /// - Parameters:
    ///   - enabled: Flag indicating if nearby device scanning is enabled.
    ///   - bluetooth: The Bluetooth Module to use for scanning.
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby. Supply `nil` to use default the default value or a value from the environment.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second. Supply `nil` to use default the default value or a value from the environment.
    ///   - autoConnect: If enabled, the bluetooth manager will automatically connect to the nearby device if only one is found.
    /// - Returns: The modified view.
    public func scanNearbyDevices(
        enabled: Bool = true, // swiftlint:disable:this function_default_parameter_at_end
        with bluetooth: Bluetooth,
        minimumRSSI: Int? = nil,
        advertisementStaleInterval: TimeInterval? = nil,
        autoConnect: Bool = false
    ) -> some View {
        scanNearbyDevices(enabled: enabled, scanner: bluetooth, state: BluetoothModuleDiscoveryState(
            minimumRSSI: minimumRSSI,
            advertisementStaleInterval: advertisementStaleInterval,
            autoConnect: autoConnect
        ))
    }

    /// Scan for nearby Bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``DiscoveryDescription`` provided in the initializer.
    /// All discovered devices can be accessed through the ``BluetoothManager/nearbyPeripherals`` property.
    ///
    /// Nearby device search is automatically paused when the view disappears or if the app enters background and
    /// is automatically started again when the view appears or the app enters the foreground again.
    /// Further, scanning is automatically started if Bluetooth is turned on by the user while the view was already presented.
    ///
    /// The auto connect feature allows you to automatically connect to a bluetooth peripheral if it is the only device
    /// discovered for a short period in time.
    ///
    /// - Tip: If you want to continuously search for auto-connectable device in the background,
    ///     you might want to use the ``SwiftUICore/View/autoConnect(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:)`` modifier instead.
    ///
    /// - Parameters:
    ///   - enabled: Flag indicating if nearby device scanning is enabled.
    ///   - bluetoothManager: The Bluetooth Manager to use for scanning.
    ///   - discovery: The set of device description describing **how** and **what** to discover.
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby. Supply `nil` to use default the default value or a value from the environment.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second. Supply `nil` to use default the default value or a value from the environment.
    ///   - autoConnect: If enabled, the bluetooth manager will automatically connect to the nearby device if only one is found.
    /// - Returns: The modified view.
    public func scanNearbyDevices(
        enabled: Bool = true, // swiftlint:disable:this function_default_parameter_at_end
        with bluetoothManager: BluetoothManager,
        discovery: Set<DiscoveryDescription>,
        minimumRSSI: Int? = nil,
        advertisementStaleInterval: TimeInterval? = nil,
        autoConnect: Bool = false
    ) -> some View {
        scanNearbyDevices(enabled: enabled, scanner: bluetoothManager, state: BluetoothManagerDiscoveryState(
            configuredDevices: discovery,
            minimumRSSI: minimumRSSI,
            advertisementStaleInterval: advertisementStaleInterval,
            autoConnect: autoConnect
        ))
    }
}
