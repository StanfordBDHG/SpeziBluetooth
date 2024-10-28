//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import NIO
import Observation
import OrderedCollections
import OSLog


/// Connect and communicate with Bluetooth devices.
///
/// This module allows to connect and communicate with Bluetooth devices using modern programming paradigms.
/// Under the hood this module uses Apple's [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth).
///
/// ### Configure the Bluetooth Manager
///
/// To configure the Bluetooth Manager, you need to specify what devices you want to discover and what services and
/// characteristics you are interested in.
/// To do so, provide a set of ``DiscoveryDescription``s upon initialization of the `BluetoothManager`.
///
/// Below is a short code example to discover devices with a Heart Rate service.
///
/// ```swift
/// let manager = BluetoothManager()
///
/// manager.scanNearbyDevices(discovery: devices [
///     DeviceDescription(discoverBy: .advertisedService("180D"), services: [
///         ServiceDescription(serviceId: "180D", characteristics: [
///             "2A37", // heart rate measurement
///             "2A38", // body sensor location
///             "2A39" // heart rate control point
///         ])
///     ])
/// ])
/// // ...
/// manager.stopScanning()
/// ```
///
/// ### Searching for nearby devices
///
/// You can scan for nearby devices using the ``scanNearbyDevices(discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)`` and stop scanning with ``stopScanning()``.
/// All discovered peripherals will be populated through the ``nearbyPeripherals`` properties.
///
/// Refer to the documentation of ``BluetoothPeripheral`` on how to interact with a Bluetooth peripheral.
///
/// - Tip: You can also use the ``SwiftUI/View/scanNearbyDevices(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)``
///     and ``SwiftUI/View/autoConnect(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:)``
///     modifiers within your SwiftUI view to automatically manage device scanning and/or auto connect to the
///     first available device.
///
/// ## Topics
///
/// ### Create a Bluetooth Manager
///
/// - ``init()``
///
/// ### Bluetooth State
///
/// - ``state``
/// - ``isScanning``
/// - ``stateSubscription``
///
/// ### Discovering nearby Peripherals
/// - ``nearbyPeripherals``
/// - ``scanNearbyDevices(discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)``
/// - ``stopScanning()``
/// - ``SwiftUI/View/scanNearbyDevices(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)``
/// - ``SwiftUI/View/autoConnect(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:)``
///
/// ### Retrieving known Peripherals
/// - ``retrievePeripheral(for:with:)``
///
/// ### Manually Manage Powered State
/// - ``powerOn()``
/// - ``powerOff()``
@SpeziBluetooth
public class BluetoothManager: Observable, Sendable, Identifiable { // swiftlint:disable:this type_body_length
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")

    private var _centralManager: CBInstance<CBCentralManager>?

    private var centralManager: CBCentralManager {
        guard let centralManager = _centralManager else {
            let centralManager = supplyCBCentral()
            self._centralManager = CBInstance(instantiatedOnDispatchQueue: centralManager)
            return centralManager
        }
        return centralManager.cbObject
    }

    private lazy var centralDelegate: Delegate = { // swiftlint:disable:this weak_delegate
        let delegate = Delegate()
        delegate.initManager(self)
        return delegate
    }()

    private var isScanningObserver: KVOStateDidChangeObserver<CBCentralManager, Bool>?

    private let storage = BluetoothManagerStorage()

    /// Flag indicating that we want the CBCentral to stay allocated.
    private var keepPoweredOn = false

    /// Currently ongoing discovery session.
    private var discoverySession: DiscoverySession?
    /// The identifier of the last manually disconnected device.
    /// This is to avoid automatically reconnecting to a device that was manually disconnected.
    private(set) var lastManuallyDisconnectedDevice: UUID?

    /// The list of nearby bluetooth devices.
    ///
    /// This array contains all discovered bluetooth peripherals and those with which we are currently connected.
    public nonisolated var nearbyPeripherals: [BluetoothPeripheral] {
        Array(storage.readOnlyDiscoveredPeripherals.values)
    }

    /// Represents the current state of the Bluetooth Manager.
    public nonisolated var state: BluetoothState {
        storage.readOnlyState
    }

    /// Subscribe to changes of the `state` property.
    ///
    /// Creates an `AsyncStream` that yields all **future** changes to the ``state`` property.
    public nonisolated var stateSubscription: AsyncStream<BluetoothState> {
        storage.stateSubscription
    }

    /// Whether or not we are currently scanning for nearby devices.
    public nonisolated var isScanning: Bool {
        storage.readOnlyIsScanning
    }

    /// The list of discovered and connected bluetooth devices indexed by their identifier UUID.
    /// The state is isolated to our `dispatchQueue`.
    var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> {
        storage.discoveredPeripherals
    }

    var retrievedPeripherals: OrderedDictionary<UUID, WeakReference<BluetoothPeripheral>> {
        storage.retrievedPeripherals
    }

    /// The combined collection of `discoveredPeripherals` and `retrievedPeripherals`.
    ///
    /// Don't store this dictionary as this will accidentally reference retrieved peripherals strongly.
    var knownPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> {
        let keysAndValues = retrievedPeripherals.elements
            .map { ($0, $1.value) }
            .compactMap { id, value in
                if let value {
                    return (id, value)
                }
                return nil
            }

        return discoveredPeripherals.merging(keysAndValues) { lhs, rhs in
            assertionFailure("Peripheral was present in both, discovered and retrieved set, lhs: \(lhs), rhs: \(rhs)")
            return lhs
        }
    }

    
    /// Initialize a new Bluetooth Manager with provided device description and optional configuration options.
    public nonisolated init() {}

    func supplyCBCentral() -> CBCentralManager {
        // The Bluetooth permission alert shows every time when a CBCentralManager is initialized.
        // If we already have permissions the a power alert will be shown if the user has Bluetooth disabled.
        // To have those alerts shown at the right time (and repeatedly), we lazily initialize the CBCentralManager and also deinit it
        // once we don't use it anymore (we are not scanning and no device is currently connected).
        // All this state handling happens here within the closures passed to the `Lazy` property wrapper.

        let central = CBCentralManager(
            delegate: centralDelegate,
            queue: SpeziBluetooth.shared.dispatchQueue,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )

        isScanningObserver = KVOStateDidChangeObserver(entity: central, property: \.isScanning) { [weak self] value in
            guard let self else {
                return
            }
            storage.isScanning = value
            if !isScanning {
                handleStoppedScanning()
            }
        }

        logger.debug("Initialized the underlying CBCentralManager.")
        return central
    }

    func cleanupCBCentral() {
        _centralManager = nil
        isScanningObserver = nil
        lastManuallyDisconnectedDevice = nil
        logger.debug("Destroyed the underlying CBCentralManager.")
    }

    /// Request to power up the Bluetooth Central.
    ///
    /// This method manually instantiates the underlying Central Manager and ensure that it stays allocated.
    /// Balance this call with a call to ``powerOff()``.
    ///
    /// - Note : The underlying `CBCentralManager` is lazily allocated and deallocated once it isn't needed anymore.
    ///     This is used to delay Bluetooth permission and power prompts to the latest possible moment avoiding unexpected interruptions.
    public func powerOn() {
        keepPoweredOn = true
        _ = centralManager // ensure it is allocated
    }

    /// Request to power down the Bluetooth Central.
    ///
    /// This method request to power off the central. This is delay if the central is still used (e.g., currently scanning or connected peripherals).
    ///
    /// - Note : The underlying `CBCentralManager` is lazily allocated and deallocated once it isn't needed anymore.
    ///     This is used to delay Bluetooth permission and power prompts to the latest possible moment avoiding unexpected interruptions.
    public func powerOff() {
        keepPoweredOn = false
        checkForCentralDeinit()
    }

    /// Scan for nearby bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``DiscoveryDescription`` provided in the initializer.
    /// All discovered devices can be accessed through the ``nearbyPeripherals`` property.
    ///
    /// - Tip: Scanning for nearby devices can easily be managed via the ``SwiftUI/View/scanNearbyDevices(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)``
    ///     modifier.
    ///
    /// - Parameters:
    ///   - discovery: The set of device description describing **how** and **what** to discover.
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second.
    ///   - autoConnect: If enabled, the bluetooth manager will automatically connect to
    ///     the nearby device if only one is found for a given time threshold.
    public func scanNearbyDevices(
        discovery: Set<DiscoveryDescription>,
        minimumRSSI: Int? = nil,
        advertisementStaleInterval: TimeInterval? = nil,
        autoConnect: Bool = false
    ) {
        let state = BluetoothManagerDiscoveryState(
            configuredDevices: discovery,
            minimumRSSI: minimumRSSI,
            advertisementStaleInterval: advertisementStaleInterval,
            autoConnect: autoConnect
        )
        scanNearbyDevices(state)
    }

    @_spi(APISupport)
    public func scanNearbyDevices(_ state: BluetoothManagerDiscoveryState) {
        guard discoverySession == nil else {
            return // already scanning!
        }

        logger.debug("Creating discovery session ...")

        let session = DiscoverySession(
            boundTo: self,
            configuration: state
        )
        self.discoverySession = session

        // if powered of, we start scanning later in `handlePoweredOn()`
        if case .poweredOn = centralManager.state {
            _scanForPeripherals(using: session)
        }
    }

    private func _scanForPeripherals(using session: DiscoverySession) {
        guard !isScanning else {
            return
        }

        logger.debug("Starting scanning for nearby devices ...")
        centralManager.scanForPeripherals(
            withServices: session.serviceDiscoveryIds?.map { $0.cbuuid },
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        storage.isScanning = centralManager.isScanning // ensure this is propagated instantly
    }

    private func _restartScanning(using session: DiscoverySession) {
        guard !isScanning else {
            return
        }

        centralManager.stopScan()
        centralManager.scanForPeripherals(
            withServices: session.serviceDiscoveryIds?.map { $0.cbuuid },
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        storage.isScanning = centralManager.isScanning // ensure this is propagated instantly
    }

    /// Stop scanning for nearby bluetooth devices.
    public func stopScanning() {
        if isScanning { // transitively checks for state == .poweredOn
            centralManager.stopScan()
            storage.isScanning = centralManager.isScanning // ensure this is synced
            logger.debug("Scanning stopped")
        }

        if discoverySession != nil {
            logger.debug("Discovery session cleared.")
            discoverySession = nil
            checkForCentralDeinit()
        }
    }


    /// Reactive scan upon powered on.
    private func handlePoweredOn() {
        if let discoverySession, !isScanning {
            _scanForPeripherals(using: discoverySession)
        }
    }

    private func handleStoppedScanning() {
        let devices = discoveredPeripherals.values.filter { device in
            device.cbPeripheral.state == .disconnected
        }

        for device in devices {
            clearDiscoveredPeripheral(forKey: device.id)
        }

        if devices.isEmpty { // otherwise deinit was already called
            checkForCentralDeinit()
        }
    }


    /// Retrieve a known `BluetoothPeripheral` by its identifier.
    ///
    /// This method queries the list of known ``BluetoothPeripheral``s (e.g., paired peripherals).
    ///
    /// - Tip: You can use this method to connect to a known peripheral. Retrieve the peripheral using this method and call the ``BluetoothPeripheral/connect()`` method.
    ///     The `connect()` method doesn't time out and will make sure to connect to the peripheral once it is available without the need for continuous scanning.
    ///
    /// - Important: Make sure to keep a strong reference to the returned peripheral. The `BluetoothManager` only keeps a weak reference to the peripheral.
    ///     If you don't need the peripheral anymore, ``BluetoothPeripheral/disconnect()`` and dereference it.
    ///
    /// - Parameters:
    ///   - uuid: The Bluetooth peripheral identifier.
    ///   - description: The expected device configuration of the peripheral. This is used to discover service and characteristics if you connect to the peripheral-
    /// - Returns: The retrieved Peripheral. Returns nil if the Bluetooth Central could not be powered on (e.g., not authorized) or if no peripheral with the requested identifier was found.
    public func retrievePeripheral(for uuid: UUID, with description: DeviceDescription) async -> BluetoothPeripheral? {
        if _centralManager == nil {
            _ = centralManager // make sure central is initialized!

            // we are waiting for the next state transition, ideally to poweredOn state!
            logger.debug("Waiting for CBCentral to power on, before retrieving peripheral.")
            for await nextState in stateSubscription {
                logger.debug("CBCentral state transitioned to state \(nextState)")
                break
            }
        }

        guard case .poweredOn = centralManager.state else {
            logger.warning("Cannot retrieve peripheral with id \(uuid) while central is not powered on \(self.state)")
            checkForCentralDeinit()
            return nil
        }

        if let peripheral = knownPeripheral(for: uuid) {
            return peripheral // peripheral was already retrieved or was recently discovered
        }

        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first else {
            checkForCentralDeinit()
            return nil
        }


        let device = BluetoothPeripheral(
            manager: self,
            peripheral: peripheral,
            configuration: description,
            advertisementData: .init([:]), // there was no advertisement
            rssi: 127 // value of 127 signifies unavailability of RSSI value
        )

        storage.retrievedPeripherals.updateValue(WeakReference(device), forKey: peripheral.identifier)

        return device
    }

    func onChange<Value>(of keyPath: KeyPath<BluetoothManagerStorage, Value>, perform closure: @escaping (Value) -> Void) {
        storage.onChange(of: keyPath, perform: closure)
    }

    func clearDiscoveredPeripheral(forKey id: UUID) {
        if let peripheral = discoveredPeripherals[id] {
            // `handleDiscarded` must be called before actually removing it from the dictionary to make sure peripherals can react to this event
            peripheral.handleDiscarded()

            // Users might keep reference to Peripheral object. Therefore, we keep it as a weak reference so we can forward delegate calls.
            storage.retrievedPeripherals[id] = WeakReference(peripheral)
        }

        storage.discoveredPeripherals.removeValue(forKey: id)

        checkForCentralDeinit()
    }

    fileprivate func knownPeripheral(for uuid: UUID) -> BluetoothPeripheral? {
        if let peripheral = discoveredPeripherals[uuid] {
            return peripheral
        }

        guard let reference = retrievedPeripherals[uuid] else {
            return nil
        }

        guard let peripheral = reference.value else {
            storage.retrievedPeripherals.removeValue(forKey: uuid)
            return nil
        }
        return peripheral
    }

    fileprivate func ensurePeripheralReference(_ peripheral: BluetoothPeripheral) {
        guard retrievedPeripherals[peripheral.id] != nil else {
            return // is not weakly referenced
        }

        storage.retrievedPeripherals[peripheral.id] = nil
        storage.discoveredPeripherals[peripheral.id] = peripheral
    }

    /// The peripheral was finally deallocated.
    ///
    /// This method makes sure that all (weak) references to the de-initialized peripheral are fully cleared.
    func handlePeripheralDeinit(id uuid: UUID) {
        storage.retrievedPeripherals.removeValue(forKey: uuid)

        checkForCentralDeinit()
    }

    /// De-initializes the Bluetooth Central if we currently don't use it.
    private func checkForCentralDeinit() {
        guard !keepPoweredOn else {
            return // requested to stay allocated
        }

        guard discoverySession == nil else {
            return // discovery is currently running
        }

        guard discoveredPeripherals.isEmpty && retrievedPeripherals.isEmpty else {
            logger.debug("""
                         Not deallocating central. Devices are still associated: \
                         discovered: \(self.discoveredPeripherals.count), \
                         retrieved: \(self.retrievedPeripherals.count)
                         """)
            return // there are still associated devices
        }

        cleanupCBCentral()
        storage.update(state: .unknown)
    }

    func connect(peripheral: BluetoothPeripheral) {
        logger.debug("Trying to connect to \(peripheral) ...")

        let cancelled = discoverySession?.cancelStaleTask(for: peripheral)

        self.centralManager.connect(peripheral.cbPeripheral, options: nil)

        if cancelled == true {
            discoverySession?.scheduleStaleTaskForOldestActivityDevice(ignore: peripheral)
        }
    }

    func disconnect(peripheral: BluetoothPeripheral) {
        logger.debug("Disconnecting peripheral \(peripheral) ...")
        // stale timer is handled in the delegate method
        centralManager.cancelPeripheralConnection(peripheral.cbPeripheral)

        lastManuallyDisconnectedDevice = peripheral.id
    }

    private func handledConnected(device: BluetoothPeripheral) async {
        // we might have connected a bluetooth peripheral that was weakly referenced
        ensurePeripheralReference(device)
        
        await device.handleConnect()
    }

    private func discardDevice(device: BluetoothPeripheral, error: Error?) {
        if let discoverySession, isScanning {
            // we will keep discarded devices for max 2s before the stale timer kicks off
            let backdateInterval = max(0, discoverySession.advertisementStaleInterval - 2)

            device.markLastActivity(.now - backdateInterval)
            device.handleDisconnect(error: error)

            // We just schedule the new timer if there is a device to schedule one for.
            discoverySession.scheduleStaleTaskForOldestActivityDevice()
        } else {
            device.markLastActivity()
            device.handleDisconnect(error: error)
            clearDiscoveredPeripheral(forKey: device.id)
        }
    }


    deinit {
        discoverySession = nil

        Task { @SpeziBluetooth [storage, _centralManager, isScanning, logger] in
            if isScanning {
                storage.isScanning = false
                _centralManager?.cbObject.stopScan()
                logger.debug("Scanning stopped")
            }

            storage.update(state: .unknown)
            storage.discoveredPeripherals = [:]
            storage.retrievedPeripherals = [:]
            logger.debug("BluetoothManager destroyed")
        }
    }
}


@_spi(APISupport)
extension BluetoothManager: BluetoothScanner {
    /// Default id based on `ObjectIdentifier`.
    public nonisolated var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }

    /// Support for the auto connect modifier.
    @_documentation(visibility: internal)
    public var hasConnectedDevices: Bool {
        storage.maHasConnectedDevices
    }

    @SpeziBluetooth var sbHasConnectedDevices: Bool {
        storage.hasConnectedDevices // support for DiscoverySession
    }

    public func updateScanningState(_ state: BluetoothManagerDiscoveryState) {
        guard let discoverySession else {
            return
        }

        let discoveryItemsChanged = discoverySession.updateConfigurationReportingDiscoveryItemsChanged(state)

        if discoveryItemsChanged == true {
            _restartScanning(using: discoverySession)
        }
    }
}


// MARK: Defaults
extension BluetoothManager {
    /// Set of default values used within the Bluetooth Manager
    enum Defaults {
        /// The default timeout after which stale advertisements are removed.
        static let defaultStaleTimeout: TimeInterval = 8
        /// The minimum rssi of a peripheral to consider it for discovery.
        static let defaultMinimumRSSI = -80
        /// The default time in seconds after which we check for auto connectable devices after the initial advertisement.
        static let defaultAutoConnectDebounce: Int = 1
        /// The amount of times we try to automatically (if enabled) subscribe to a notify characteristic.
        static let autoSubscribeAttempts = 3
    }
}


// MARK: Delegate
extension BluetoothManager {
    private class Delegate: NSObject, CBCentralManagerDelegate {
        private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManagerDelegate")

        private weak var manager: BluetoothManager?


        override init() {
            super.init()
        }

        func initManager(_ manager: BluetoothManager) {
            self.manager = manager
        }

        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            let state = BluetoothState(from: central.state)

            guard let manager else {
                return
            }

            // All these delegate methods are actually running on the DispatchQueue the Actor is isolated to.
            // So in theory we should just be able to jump into isolation with assumeIsolated().
            // However, executing a scheduled Job is different to just running a scheduled Job in the dispatch queue
            // form a Swift Runtime perspective.
            // Refer to _isCurrentExecutor (checked in assumeIsolated):
            // https://github.com/apple/swift/blob/9e2b97c0fd675efaa5b815748d8567d781415c8c/stdlib/public/Concurrency/Actor.cpp#L317
            // Also refer to te implementation of assumeIsolated:
            // https://github.com/apple/swift/blob/a1062d06e9f33512b0005d589e3b086a89cfcbd1/stdlib/public/Concurrency/ExecutorAssertions.swift#L351-L372.
            // We could just cast the closure to be isolated (nothing else does assumeIsolated), however we would not have the
            // same Runtime state as an executing Task that is actor isolated.
            // So whats the solution? We schedule onto a background SerialExecutor (@SpeziBluetooth) so we maintain execution
            // order and make sure to capture all important state before that.
            Task { @SpeziBluetooth [logger] in
                manager.storage.update(state: state)
                logger.info("BluetoothManager central state is now \(manager.state)")

                if case .poweredOn = state {
                    manager.handlePoweredOn()
                } else if case .unauthorized = state {
                    switch CBCentralManager.authorization {
                    case .denied:
                        logger.log("Unauthorized reason: Access to Bluetooth was denied.")
                    case .restricted:
                        logger.log("Unauthorized reason: Bluetooth is restricted.")
                    default:
                        break
                    }
                }
            }
        }

        func centralManager(
            _ central: CBCentralManager,
            didDiscover peripheral: CBPeripheral,
            advertisementData: [String: Any],
            // We have to use NSNumber to conform to the `CBCentralManagerDelegate` delegate methods.
            // swiftlint:disable:next legacy_objc_type
            rssi: NSNumber
        ) {
            guard let manager else {
                return
            }

            let data = AdvertisementData(advertisementData)

            let peripheral = CBInstance(instantiatedOnDispatchQueue: peripheral)

            Task { @SpeziBluetooth [logger, data] in
                guard let session = manager.discoverySession,
                      manager.isScanning else {
                    return
                }

                // ensure the signal strength is not too low
                guard session.isInRange(rssi: rssi) else {
                    return // logging this would just be to verbose, so we don't.
                }


                // check if we already seen this device!
                if let device = manager.knownPeripheral(for: peripheral.identifier) {
                    device.markLastActivity()
                    device.update(advertisement: data, rssi: rssi.intValue)

                    // we might have discovered a previously "retrieved" peripheral that must be strongly referenced now
                    manager.ensurePeripheralReference(device)

                    session.deviceDiscoveryPostAction(device: device, newlyDiscovered: false)
                    return
                }

                logger.debug("Discovered peripheral \(peripheral.debugIdentifier) at \(rssi.intValue) dB with data \(data)")

                let descriptor = session.configuredDevices.find(for: data, logger: logger)

                let device = BluetoothPeripheral(
                    manager: manager,
                    peripheral: peripheral.cbObject,
                    configuration: descriptor?.device ?? DeviceDescription(),
                    advertisementData: data,
                    rssi: rssi.intValue
                )
                // save local-copy, such CB doesn't deallocate it
                manager.storage.discoveredPeripherals.updateValue(device, forKey: peripheral.identifier)


                session.deviceDiscoveryPostAction(device: device, newlyDiscovered: true)
            }
        }

        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            guard let manager else {
                return
            }

            let peripheral = CBInstance(instantiatedOnDispatchQueue: peripheral)
            Task { @SpeziBluetooth [logger] in
                guard let device = manager.knownPeripheral(for: peripheral.identifier) else {
                    logger.error("Received didConnect for unknown peripheral \(peripheral.debugIdentifier). Cancelling connection ...")
                    manager.centralManager.cancelPeripheralConnection(peripheral.cbObject)
                    return
                }

                logger.debug("Peripheral \(device) connected.")
                await manager.storage.cbDelegateSignal(connected: true, for: peripheral.identifier)

                await manager.handledConnected(device: device)
            }
        }

        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            guard let manager else {
                return
            }

            // Documentation reads: "Because connection attempts don’t time out, a failed connection usually indicates a transient issue,
            // in which case you may attempt connecting to the peripheral again."

            let peripheral = CBInstance(instantiatedOnDispatchQueue: peripheral)

            Task { @SpeziBluetooth [logger] in
                guard let device = manager.knownPeripheral(for: peripheral.identifier) else {
                    logger.warning("Unknown peripheral \(peripheral.debugIdentifier) failed with error: \(String(describing: error))")
                    manager.centralManager.cancelPeripheralConnection(peripheral.cbObject)
                    return
                }

                if let error {
                    logger.error("Failed to connect to \(device): \(error)")
                } else {
                    logger.error("Failed to connect to \(device)")
                }

                // just to make sure
                manager.centralManager.cancelPeripheralConnection(device.cbPeripheral)

                manager.discardDevice(device: device, error: error)
            }
        }


        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            guard let manager else {
                return
            }

            let peripheral = CBInstance(instantiatedOnDispatchQueue: peripheral)
            Task { @SpeziBluetooth [logger] in
                guard let device = manager.knownPeripheral(for: peripheral.identifier) else {
                    logger.error("Received didDisconnect for unknown peripheral \(peripheral.debugIdentifier).")
                    return
                }

                if let error {
                    logger.debug("Peripheral \(device) disconnected due to an error: \(error)")
                } else {
                    logger.debug("Peripheral \(device) disconnected.")
                }

                manager.discardDevice(device: device, error: error)
                await manager.storage.cbDelegateSignal(connected: false, for: peripheral.identifier)
            }
        }
    }
}

// swiftlint:disable:this file_length
