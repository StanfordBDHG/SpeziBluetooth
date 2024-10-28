//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog

private func optionalMax<Value: Comparable>(_ lhs: Value?, _ rhs: Value?) -> Value? {
    guard let lhs, let rhs else {
        return lhs ?? rhs
    }
    return max(lhs, rhs)
}


@_spi(APISupport)
public struct BluetoothManagerDiscoveryState: BluetoothScanningState {
    /// The device descriptions describing how nearby devices are discovered.
    let configuredDevices: Set<DiscoveryDescription>
    /// The minimum rssi that is required for a device to be considered discovered.
    let minimumRSSI: Int?
    /// The time interval after which an advertisement is considered stale and the device is removed.
    let advertisementStaleInterval: TimeInterval?
    /// Flag indicating if first discovered device should be auto-connected.
    let autoConnect: Bool


    init(configuredDevices: Set<DiscoveryDescription>, minimumRSSI: Int?, advertisementStaleInterval: TimeInterval?, autoConnect: Bool) {
        self.configuredDevices = configuredDevices
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = advertisementStaleInterval.map { max(1, $0) }
        self.autoConnect = autoConnect
    }

    public func merging(with other: BluetoothManagerDiscoveryState) -> BluetoothManagerDiscoveryState {
        BluetoothManagerDiscoveryState(
            configuredDevices: configuredDevices.union(other.configuredDevices),
            minimumRSSI: optionalMax(minimumRSSI, other.minimumRSSI),
            advertisementStaleInterval: optionalMax(advertisementStaleInterval, other.advertisementStaleInterval),
            autoConnect: autoConnect || other.autoConnect
        )
    }

    public func updateOptions(minimumRSSI: Int?, advertisementStaleInterval: TimeInterval?) -> BluetoothManagerDiscoveryState {
        BluetoothManagerDiscoveryState(
            configuredDevices: configuredDevices,
            minimumRSSI: optionalMax(self.minimumRSSI, minimumRSSI),
            advertisementStaleInterval: optionalMax(self.advertisementStaleInterval, advertisementStaleInterval),
            autoConnect: autoConnect
        )
    }
}


/// Intermediate storage object that is later translated to a BluetoothManagerDiscoveryState.
@_spi(APISupport)
public struct BluetoothModuleDiscoveryState: BluetoothScanningState {
    /// The minimum rssi that is required for a device to be considered discovered.
    let minimumRSSI: Int?
    /// The time interval after which an advertisement is considered stale and the device is removed.
    let advertisementStaleInterval: TimeInterval?
    /// Flag indicating if first discovered device should be auto-connected.
    let autoConnect: Bool


    init(minimumRSSI: Int?, advertisementStaleInterval: TimeInterval?, autoConnect: Bool) {
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = advertisementStaleInterval
        self.autoConnect = autoConnect
    }

    public func merging(with other: BluetoothModuleDiscoveryState) -> BluetoothModuleDiscoveryState {
        BluetoothModuleDiscoveryState(
            minimumRSSI: optionalMax(minimumRSSI, other.minimumRSSI),
            advertisementStaleInterval: optionalMax(advertisementStaleInterval, other.advertisementStaleInterval),
            autoConnect: autoConnect || other.autoConnect
        )
    }

    public func updateOptions(minimumRSSI: Int?, advertisementStaleInterval: TimeInterval?) -> BluetoothModuleDiscoveryState {
        BluetoothModuleDiscoveryState(
            minimumRSSI: optionalMax(self.minimumRSSI, minimumRSSI),
            advertisementStaleInterval: optionalMax(self.advertisementStaleInterval, advertisementStaleInterval),
            autoConnect: autoConnect
        )
    }
}


@SpeziBluetooth
class DiscoverySession: Sendable {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "DiscoverySession")


    fileprivate weak var manager: BluetoothManager?

    private var configuration: BluetoothManagerDiscoveryState

    private var autoConnectItem: BluetoothWorkItem?
    private(set) var staleTimer: DiscoveryStaleTimer?

    private var connectionAttempt: Task<Void, Error>? {
        willSet {
            connectionAttempt?.cancel()
        }
    }

    var configuredDevices: Set<DiscoveryDescription> {
        configuration.configuredDevices
    }

    var minimumRSSI: Int {
        configuration.minimumRSSI ?? BluetoothManager.Defaults.defaultMinimumRSSI
    }

    var advertisementStaleInterval: TimeInterval {
        configuration.advertisementStaleInterval ?? BluetoothManager.Defaults.defaultStaleTimeout
    }

    /// The set of serviceIds we request to discover upon scanning.
    /// Returning nil means scanning for all peripherals.
    var serviceDiscoveryIds: [BTUUID]? { // swiftlint:disable:this discouraged_optional_collection
        let discoveryIds = configuration.configuredDevices.flatMap { configuration in
            configuration.discoveryCriteria.discoveryIds
        }

        return discoveryIds.isEmpty ? nil : discoveryIds
    }


    init(
        boundTo manager: BluetoothManager,
        configuration: BluetoothManagerDiscoveryState
    ) {
        self.manager = manager
        self.configuration = configuration
    }

    func isInRange(rssi: NSNumber) -> Bool {
        // rssi of 127 is a magic value signifying unavailability of the value.
        rssi.intValue >= minimumRSSI && rssi.intValue != 127
    }

    func deviceDiscoveryPostAction(device: BluetoothPeripheral, newlyDiscovered: Bool) {
        if newlyDiscovered {
            if staleTimer == nil {
                // There is no stale timer running. So new device will be the one with the oldest activity. Schedule ...
               scheduleStaleTask(for: device, withTimeout: advertisementStaleInterval)
            }
        } else {
            if cancelStaleTask(for: device) {
                // current device was earliest to go stale, schedule timeout for next oldest device
                scheduleStaleTaskForOldestActivityDevice()
            }
        }

        kickOffAutoConnect()
    }

    func updateConfigurationReportingDiscoveryItemsChanged(_ configuration: BluetoothManagerDiscoveryState) -> Bool {
        let discoveryItemsChanged = self.configuration.configuredDevices != configuration.configuredDevices
        self.configuration = configuration
        return discoveryItemsChanged
    }
}


extension BluetoothManagerDiscoveryState: Hashable {}


extension BluetoothModuleDiscoveryState: Hashable {}

// MARK: - Auto Connect

extension DiscoverySession {
    /// Checks and determines the device candidate for auto-connect.
    ///
    /// This will deliver a matching candidate with the lowest RSSI if we don't have a device already connected,
    /// and there wasn't a device manually disconnected.
    private var autoConnectDeviceCandidate: BluetoothPeripheral? {
        guard let manager else {
            return nil // we are orphaned
        }

        guard configuration.autoConnect else {
            return nil // auto-connect is disabled
        }

        guard manager.lastManuallyDisconnectedDevice == nil && !manager.sbHasConnectedDevices else {
            return nil
        }

        let sortedCandidates = manager.discoveredPeripherals
            .values
            .filter { $0.cbPeripheral.state == .disconnected }
            .sorted { lhs, rhs in
                lhs.rssi < rhs.rssi
            }

        return sortedCandidates.first
    }


    func kickOffAutoConnect() {
        guard autoConnectItem == nil && autoConnectDeviceCandidate != nil else {
            return
        }

        let item = BluetoothWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.autoConnectItem = nil

            guard let candidate = self.autoConnectDeviceCandidate else {
                return
            }

            guard connectionAttempt == nil else {
                return
            }

            connectionAttempt = Task { @SpeziBluetooth [weak self] in
                defer {
                    self?.connectionAttempt = nil
                }
                try await candidate.connect()
            }
        }

        item.schedule(for: .now() + .seconds(BluetoothManager.Defaults.defaultAutoConnectDebounce))
        autoConnectItem = item
    }
}

// MARK: - Stale Advertisement Timeout

extension DiscoverySession {
    /// Schedule a new `DiscoveryStaleTimer`, cancelling any previous one.
    /// - Parameters:
    ///   - device: The device for which the timer is scheduled for.
    ///   - timeout: The timeout for which the timer is scheduled for.
    func scheduleStaleTask(for device: BluetoothPeripheral, withTimeout timeout: TimeInterval) {
        let timer = DiscoveryStaleTimer(device: device.id) { [weak self] in
            self?.handleStaleTask()
        }

        self.staleTimer = timer
        timer.schedule(for: timeout, in: SpeziBluetooth.shared.dispatchQueue)
    }

    func scheduleStaleTaskForOldestActivityDevice(ignore device: BluetoothPeripheral? = nil) {
        if let oldestActivityDevice = oldestActivityDevice(ignore: device) {
            let lastActivity = oldestActivityDevice.lastActivity

            let intervalSinceLastActivity = Date.now.timeIntervalSince(lastActivity)
            let nextTimeout = max(0, advertisementStaleInterval - intervalSinceLastActivity)

            scheduleStaleTask(for: oldestActivityDevice, withTimeout: nextTimeout)
        }
    }

    func cancelStaleTask(for device: BluetoothPeripheral) -> Bool {
        guard let staleTimer, staleTimer.targetDevice == device.id else {
            return false
        }

        staleTimer.cancel()
        self.staleTimer = nil
        return true
    }

    /// The device with the oldest device activity.
    /// - Parameter device: The device to ignore.
    private func oldestActivityDevice(ignore device: BluetoothPeripheral? = nil) -> BluetoothPeripheral? {
        guard let manager else {
            return nil
        }

        // when we are just interested in the min device, this operation is a bit cheaper then sorting the whole list
        return manager.discoveredPeripherals
            .values
            .filter {
                // it's important to access the underlying state here
                $0.cbPeripheral.state == .disconnected && $0.id != device?.id
            }
            .min { lhs, rhs in
                lhs.lastActivity < rhs.lastActivity
            }
    }

    private func handleStaleTask() {
        guard let manager else {
            return
        }

        staleTimer = nil // reset the timer

        let staleInternal = advertisementStaleInterval
        let staleDevices = manager.discoveredPeripherals
            .values
            .filter { device in
                device.isConsideredStale(interval: staleInternal)
            }

        for device in staleDevices {
            logger.debug("Removing stale peripheral \(device)")
            // we know it won't be connected, therefore we just need to remove it
            manager.clearDiscoveredPeripheral(forKey: device.id)
        }


        // schedule the next timeout for devices in the list
        scheduleStaleTaskForOldestActivityDevice()
    }
}
