//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation
import OSLog
import SpeziFoundation


/// A nearby Bluetooth peripheral.
///
/// This class represents a nearby Bluetooth peripheral.
/// You may connect to the peripheral and read or write its characteristic data.
///
/// ## Topics
///
/// ### Peripheral State
/// - ``id``
/// - ``name``
/// - ``state``
/// - ``rssi``
/// - ``advertisementData``
/// - ``nearby``
/// - ``lastActivity``
///
/// ### Accessing Services
/// - ``services``
/// - ``getService(id:)``
/// - ``getCharacteristic(id:on:)``
///
/// ### Managing Connection
/// - ``connect()``
/// - ``disconnect()-1nrzk``
///
/// ### Reading a value
/// - ``read(characteristic:)``
///
/// ### Writing a value
/// - ``write(data:for:)``
/// - ``writeWithoutResponse(data:for:)``
///
/// ### Notifications and handling changes
/// - ``enableNotifications(_:serviceId:characteristicId:)``
/// - ``setNotifications(_:for:)``
/// - ``registerOnChangeHandler(service:characteristic:_:)``
/// - ``registerOnChangeHandler(for:_:)``
/// - ``OnChangeRegistration``
///
/// ### Retrieving the latest signal strength
/// - ``readRSSI()``
@SpeziBluetooth
public class BluetoothPeripheral { // swiftlint:disable:this type_body_length
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothDevice")

    private weak var manager: BluetoothManager?
    let cbPeripheral: CBPeripheral
    private let configuration: DeviceDescription

    private let delegate: Delegate // swiftlint:disable:this weak_delegate
    private var stateObserver: KVOStateDidChangeObserver<CBPeripheral, CBPeripheralState>?

    /// Observable state container for local state.
    private let storage: PeripheralStorage

    /// Managed asynchronous accesses for an ongoing connection attempt.
    private let connectAccess = ManagedAsynchronousAccess<Void, Error>()
    /// Managed asynchronous accesses for an ongoing disconnect attempt.
    private let disconnectAccess = ManagedAsynchronousAccess<Void, Never>()
    /// Manage asynchronous accesses per characteristic.
    private let characteristicAccesses = CharacteristicAccesses()
    /// Managed asynchronous accesses for an ongoing writhe without response.
    private let writeWithoutResponseAccess = ManagedAsynchronousAccess<Void, Never>()
    /// Managed asynchronous accesses for the rssi read action.
    private let rssiAccess = ManagedAsynchronousAccess<Int, Error>()
    /// Managed asynchronous accesses for service discovery.
    private let discoverServicesAccess = ManagedAsynchronousAccess<[BTUUID], Error>()
    /// Managed asynchronous accesses for characteristic discovery of a given service.
    private var discoverCharacteristicAccesses: [BTUUID: ManagedAsynchronousAccess<Void, Error>] = [:]

    /// On-change handler registrations for all characteristics.
    private var onChangeHandlers: [CharacteristicLocator: [UUID: CharacteristicOnChangeHandler]] = [:]
    /// The list of characteristics that are requested to enable notifications.
    private var notifyRequested: Set<CharacteristicLocator> = []
    /// A set of characteristics identifier which is populated while the initial value is being read.
    private var currentlyReadingInitialValue: Set<CharacteristicLocator> = []

    /// The internally managed identifier for the peripheral.
    public nonisolated let id: UUID

    /// The name of the peripheral.
    ///
    /// Returns the name reported through the Generic Access Profile, otherwise falls back to the local name.
    nonisolated public var name: String? {
        storage.name
    }

    /// The current signal strength.
    ///
    /// This value is automatically updated when the device is advertising.
    /// Once the device establishes a connection this has to be manually updated.
    public nonisolated var rssi: Int {
        storage.readOnlyRssi
    }

    /// The advertisement data of the last bluetooth advertisement.
    public nonisolated var advertisementData: AdvertisementData {
        storage.readOnlyAdvertisementData
    }

    /// The current peripheral device state.
    public nonisolated var state: PeripheralState {
        storage.readOnlyState
    }

    /// The list of discovered services.
    ///
    /// Services are discovered automatically upon connection
    public var services: [GATTService]? { // swiftlint:disable:this discouraged_optional_collection
        storage.services.map { Array($0.values) }
    }

    /// The last device activity.
    ///
    /// Returns the date of the last advertisement received from the device or the point in time the device disconnected.
    /// Returns `now` if the device is currently connected.
    nonisolated public var lastActivity: Date {
        if case .connected = state {
            // we are currently connected or connecting/disconnecting, therefore last activity is defined as "now"
            .now
        } else {
            storage.readOnlyLastActivity
        }
    }

    /// Indicates that the peripheral is nearby.
    ///
    /// A device is nearby if either we consider it discovered because we are currently scanning or the device is connected.
    nonisolated public var nearby: Bool {
        storage.readOnlyNearby
    }


    init(
        manager: BluetoothManager,
        peripheral: CBPeripheral,
        configuration: DeviceDescription,
        advertisementData: AdvertisementData,
        rssi: Int
    ) {
        self.manager = manager
        self.cbPeripheral = peripheral
        self.configuration = configuration

        self.id = peripheral.identifier

        self.storage = PeripheralStorage(
            peripheralName: peripheral.name,
            rssi: rssi,
            advertisementData: advertisementData,
            state: .init(from: peripheral.state)
        )

        let delegate = Delegate()

        self.delegate = delegate

        self.stateObserver = KVOStateDidChangeObserver(entity: peripheral, property: \.state) { [weak self] value in
            self?.storage.update(state: PeripheralState(from: value))
        }

        // we have this separate initDevice method as otherwise above access to `delegate`
        // would become non-isolated accesses (due to usage of self beforehand).
        delegate.initDevice(self)

        peripheral.delegate = delegate
    }

    /// Establish a connection to the peripheral and wait until it is connected.
    ///
    /// Make a connection to the peripheral. The method returns once the device is connected and fully discovered according to
    /// the ``DeviceDescription`` (e.g., enabling notifications for certain characteristics).
    /// If service or characteristic discovery fails, this method will throw the respective error and automatically disconnect the device.
    ///
    /// - Note: You might want to verify via the ``AdvertisementData/isConnectable`` property that the device is connectable.
    public func connect() async throws {
        guard let manager else {
            logger.warning("Tried to connect an orphaned bluetooth peripheral!")
            return
        }

        guard manager.state == .poweredOn else {
            // CoreBluetooth only prints a "API MISUSE" log warning if one attempts to connect while not being poweredOn
            throw BluetoothError.invalidState(manager.state)
        }

        try await withTaskCancellationHandler {
            try await connectAccess.perform {
                manager.connect(peripheral: self)
            }
        } onCancel: {
            Task { @SpeziBluetooth in
                if connectAccess.ongoingAccess {
                    await disconnect()
                }
            }
        }
    }

    /// Disconnect the ongoing connection to the peripheral.
    ///
    /// Cancels an active or pending connection to a peripheral.
    @available(*, deprecated, message: "Please migrate to the async version of disconnect().")
    @_documentation(visibility: internal)
    public func disconnect() {
        Task {
            await disconnect()
        }
    }
    
    /// Disconnect the ongoing connection to the peripheral.
    ///
    /// Cancels an active or pending connection to a peripheral.
    public func disconnect() async {
        guard let manager else {
            logger.warning("Tried to disconnect an orphaned bluetooth peripheral!")
            return
        }

        removeAllNotifications()

        guard case .poweredOn = manager.state else {
            // CoreBluetooth only prints a "API MISUSE" log warning if one attempts to connect while not being poweredOn
            return
        }

        if case .disconnected = state {
            manager.disconnect(peripheral: self) // just be save and call it anyways
            return // the delegate will not be called if already disconnected
        }

        do {
            try await disconnectAccess.perform {
                manager.disconnect(peripheral: self)
                // ensure that it is updated instantly.
                storage.update(state: PeripheralState(from: cbPeripheral.state))
            }
        } catch {
            // "perform" just throws because of cancellation
        }
    }

    /// Retrieve a service.
    /// - Parameter id: The Bluetooth service id.
    /// - Returns: The service instance if present.
    public func getService(id: BTUUID) -> GATTService? {
        storage.services?[id]
    }

    /// Retrieve a characteristic.
    /// - Parameters:
    ///   - characteristicId: The Bluetooth characteristic id.
    ///   - serviceId: The Bluetooth service id.
    /// - Returns: The characteristic instance if present.
    public func getCharacteristic(id characteristicId: BTUUID, on serviceId: BTUUID) -> GATTCharacteristic? {
        getService(id: serviceId)?.getCharacteristic(id: characteristicId)
    }

    func onChange<Value>(of keyPath: KeyPath<PeripheralStorage, Value>, perform closure: @escaping (Value) -> Void) {
        storage.onChange(of: keyPath, perform: closure)
    }

    func isReadingInitialValue(for characteristicId: BTUUID, on serviceId: BTUUID) -> Bool {
        let locator = CharacteristicLocator(serviceId: serviceId, characteristicId: characteristicId)
        return currentlyReadingInitialValue.contains(locator)
    }

    func handleConnect() async {
        // ensure that it is updated instantly.
        storage.update(state: PeripheralState(from: cbPeripheral.state))

        logger.debug("Discovering services for \(self) ...")
        let serviceIds = configuration.services?.reduce(into: Set()) { result, description in
            result.insert(description.serviceId)
        }

        do {
            let discoveredServices = try await self.discoverServices(serviceIds)
            let serviceDiscoveries = try await discoverCharacteristics(for: discoveredServices)

            // handle auto-subscribe and discover descriptors if descriptions exist
            try await withThrowingDiscardingTaskGroup { group in
                for (service, descriptions) in serviceDiscoveries {
                    group.addTask { @Sendable @SpeziBluetooth in
                        try await self.enableNotificationsForDiscoveredCharacteristics(for: service)
                    }

                    if let descriptions {
                        group.addTask { @Sendable @SpeziBluetooth in
                            try await self.handleDiscoveredCharacteristic(descriptions, for: service)
                        }
                    }
                }
            }
        } catch {
            logger.error("Failed to discover initial services: \(error)")
            connectAccess.resume(throwing: error)
            await disconnect()
            return
        }

        storage.signalFullyDiscovered()
        connectAccess.resume()
    }

    private func discoverServices(_ services: Set<BTUUID>?) async throws -> [BTUUID] { // swiftlint:disable:this discouraged_optional_collection
        let cbServiceIds = services.map { $0.map { $0.cbuuid } }

        if let services {
            logger.debug("Discovering services for peripheral \(self): \(services)")
        } else {
            logger.debug("Discovering all services for peripheral \(self)")
        }

        return try await discoverServicesAccess.perform {
            cbPeripheral.discoverServices(cbServiceIds)
        }
    }

    private func discoverCharacteristics(
        for discoveredServices: [BTUUID]
    ) async throws -> [(service: GATTService, characteristics: Set<CharacteristicDescription>?)] {
        // swiftlint:disable:previous discouraged_optional_collection

        // swiftlint:disable:next discouraged_optional_collection
        let discoveryJobs: [(service: GATTService, characteristics: Set<CharacteristicDescription>?)] = discoveredServices
            .reduce(into: []) { partialResult, serviceId in
                guard let service = getService(id: serviceId),
                      let serviceDescription = configuration.description(for: serviceId) else {
                    return
                }

                partialResult.append((service, serviceDescription.characteristics))
            }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for job in discoveryJobs {
                group.addTask { @Sendable @SpeziBluetooth in
                    let characteristicIds = job.characteristics.map { Set($0.map { $0.characteristicId }) }
                    try await self.discoverCharacteristic(characteristicIds, for: job.service)
                }
            }

            try await group.waitForAll()
        }

        return discoveryJobs
    }

    private func discoverCharacteristic(_ characteristics: Set<BTUUID>?, for service: GATTService) async throws {
        // swiftlint:disable:previous discouraged_optional_collection
        let cbCharacteristicIds = characteristics.map { Array($0.map { $0.cbuuid }) }

        if let characteristics {
            logger.debug("Discovering characteristics on \(service) for peripheral \(self): \(characteristics)")
        } else {
            logger.debug("Discovering all characteristics on \(service) for peripheral \(self)")
        }

        let access: ManagedAsynchronousAccess<Void, Error>
        if let existing = discoverCharacteristicAccesses[service.id] {
            access = existing
        } else {
            access = .init()
            discoverCharacteristicAccesses[service.id] = access
        }

        try await access.perform {
            cbPeripheral.discoverCharacteristics(cbCharacteristicIds, for: service.underlyingService)
        }
    }

    private func handleDiscoveredCharacteristic(_ descriptions: Set<CharacteristicDescription>, for service: GATTService) async throws {
        try await withThrowingDiscardingTaskGroup { group in
            for description in descriptions {
                guard let characteristic = getCharacteristic(id: description.characteristicId, on: service.id) else {
                    continue
                }

                // pull initial value if none is present
                if description.autoRead && characteristic.value == nil && characteristic.properties.contains(.read) {
                    group.addTask { @Sendable  @SpeziBluetooth in
                        let locator = CharacteristicLocator(serviceId: service.id, characteristicId: characteristic.id)
                        let (inserted, _) = self.currentlyReadingInitialValue.insert(locator)
                        do {
                            _ = try await self.read(characteristic: characteristic)
                        } catch {
                            self.logger.warning("Failed to read the initial value of \(characteristic): \(error)")
                        }
                        if inserted {
                            self.currentlyReadingInitialValue.remove(locator)
                        }
                    }
                }

                if description.discoverDescriptors {
                    logger.debug("Discovering descriptors for \(characteristic)...")
                    // Currently descriptor interactions aren't really supported by SpeziBluetooth. However, we support the initial
                    // discovery of descriptors. Therefore, it is fine that this operation is currently not made fully async.
                    cbPeripheral.discoverDescriptors(for: characteristic.underlyingCharacteristic)
                }
            }
        }
    }

    private func enableNotificationsForDiscoveredCharacteristics(for service: GATTService) async throws {
        try await withThrowingDiscardingTaskGroup { group in
            for characteristic in service.characteristics {
                guard characteristic.properties.supportsNotifications,
                      didRequestNotifications(serviceId: service.id, characteristicId: characteristic.id) else {
                    continue
                }

                group.addTask { @Sendable @SpeziBluetooth in
                    self.logger.debug("Automatically subscribing to discovered characteristic \(characteristic.id) on \(service.id)...")

                    var attempts = BluetoothManager.Defaults.autoSubscribeAttempts
                    while true {
                        do {
                            try await self.setNotifications(true, for: characteristic)
                            break
                        } catch {
                            attempts -= 1
                            if attempts <= 0 {
                                throw error
                            }
                        }
                    }
                }
            }
        }
    }

    /// Handles a disconnect or failed connection attempt.
    func handleDisconnect(error: Error?) {
        // ensure that it is updated instantly.
        storage.update(state: PeripheralState(from: cbPeripheral.state))

        // clear all the ongoing access

        if let serviceIds = storage.services?.keys {
            self.invalidateServices(Set(serviceIds))
        }

        disconnectAccess.resume() // the error describes the disconnect reason, but the disconnect itself cannot throw

        connectAccess.cancelAll(error: error)
        writeWithoutResponseAccess.cancelAll()
        rssiAccess.cancelAll(error: error)
        discoverServicesAccess.cancelAll(error: error)

        characteristicAccesses.cancelAll(disconnectError: error)

        let discoverCharacteristicAccesses = discoverCharacteristicAccesses
        self.discoverCharacteristicAccesses.removeAll()
        for access in discoverCharacteristicAccesses.values {
            access.cancelAll(error: error)
        }
    }

    func handleDiscarded() {
        storage.nearby = false
    }

    func markLastActivity(_ lastActivity: Date = .now) {
        storage.lastActivity = lastActivity
    }

    func update(advertisement: AdvertisementData, rssi: Int) {
        storage.advertisementData = advertisement
        storage.rssi = rssi
        storage.nearby = true
    }

    /// Determines if the device is considered stale.
    ///
    /// This is the case if the device is not connected and the last activity is longer in the past than
    /// the provided interval.
    /// - Parameter interval: The time interval after which the device is considered stale.
    /// - Returns: True if the device is considered stale given the above criteria.
    func isConsideredStale(interval: TimeInterval) -> Bool {
        cbPeripheral.state == .disconnected && lastActivity.addingTimeInterval(interval) < .now
    }

    /// Register a on-change handler for a characteristic.
    ///
    /// This method registers a on-change handler for the provided characteristic.
    ///
    /// - Note: Make sure that you don't create a retain cycle if the provided closure captures `self`.
    ///
    /// - Parameters:
    ///   - characteristic: The characteristic to register notifications for.
    ///   - onChange: The on-change handler.
    /// - @Returns: Returns the ``OnChangeRegistration`` that can be used to cancel and deregister the on-change handler.
    public func registerOnChangeHandler(
        for characteristic: GATTCharacteristic,
        _ onChange: @escaping (Data) -> Void
    ) throws -> OnChangeRegistration {
        guard let service = characteristic.service else {
            throw BluetoothError.notPresent(service: nil, characteristic: characteristic.id)
        }

        return registerOnChangeHandler(service: service.id, characteristic: characteristic.id, onChange)
    }

    /// Register a on-change handler for a characteristic.
    ///
    /// This method registers a on-change handler for the provide service and characteristic id.
    ///
    /// - Note: Make sure that you don't create a retain cycle if the provided closure captures `self`.
    ///
    /// - Parameters:
    ///   - service: The service uuid.
    ///   - characteristic: The characteristic uuid.
    ///   - onChange: The on-change handler.
    /// - @Returns: Returns the ``OnChangeRegistration`` that can be used to cancel and deregister the on-change handler.
    public func registerOnChangeHandler(
        service: BTUUID,
        characteristic: BTUUID,
        _ onChange: @escaping (Data) -> Void
    ) -> OnChangeRegistration {
        registerCharacteristicOnChange(service: service, characteristic: characteristic, .value(onChange))
    }

    func registerOnChangeCharacteristicHandler(
        service: BTUUID,
        characteristic: BTUUID,
        _ onChange: @escaping (GATTCharacteristic?) -> Void
    ) -> OnChangeRegistration {
        registerCharacteristicOnChange(service: service, characteristic: characteristic, .instance(onChange))
    }

    private func registerCharacteristicOnChange(
        service: BTUUID,
        characteristic: BTUUID,
        _ onChange: CharacteristicOnChangeHandler
    ) -> OnChangeRegistration {
        let locator = CharacteristicLocator(serviceId: service, characteristicId: characteristic)
        let id = UUID() // on-change handler id, used internally

        let replaced = onChangeHandlers[locator, default: [:]]
            .updateValue(onChange, forKey: id)
        assert(replaced == nil, "onChangeHandlers are forced to be unique and shouldn't replace previous values.")

        return OnChangeRegistration(peripheral: self, locator: locator, handlerId: id)
    }

    func deregisterOnChange(_ registration: OnChangeRegistration) {
        deregisterOnChange(locator: registration.locator, handlerId: registration.handlerId)
    }

    func deregisterOnChange(locator: CharacteristicLocator, handlerId: UUID) {
        onChangeHandlers[locator]?.removeValue(forKey: handlerId)
    }

    /// Enable or disable notifications for a given characteristic.
    ///
    /// It is not required that the device is connected. Notifications will be automatically enabled for the
    /// respective characteristic upon device discovery.
    ///
    /// - Parameters:
    ///   - enabled: Enable or disable notifications.
    ///   - serviceId: The service the characteristic lives on.
    ///   - characteristicId: The characteristic to notify about.
    public func enableNotifications(_ enabled: Bool = true, serviceId: BTUUID, characteristicId: BTUUID) {
        // swiftlint:disable:previous function_default_parameter_at_end
        let id = CharacteristicLocator(serviceId: serviceId, characteristicId: characteristicId)

        if enabled {
            notifyRequested.insert(id)
        } else {
            notifyRequested.remove(id)
        }

        // if setting notify doesn't work here, we do it upon discovery of the characteristics
        guard let characteristic = getCharacteristic(id: characteristicId, on: serviceId) else {
            return
        }

        if characteristic.properties.supportsNotifications {
            Task {
                try? await setNotifications(enabled, for: characteristic)
            }
        }
    }

    func didRequestNotifications(serviceId: BTUUID, characteristicId: BTUUID) -> Bool {
        let id = CharacteristicLocator(serviceId: serviceId, characteristicId: characteristicId)
        return notifyRequested.contains(id)
    }

    /// Set notification value for a given characteristic.
    ///
    /// In contrast to ``enableNotifications(_:serviceId:characteristicId:)`` this method instantly sends the command to the peripheral and awaits the response.
    /// Therefore, the device must be connected when calling this method.
    ///
    /// - Parameters:
    ///   - enabled: Enable or disable notifications.
    ///   - characteristic: The characteristic for which to enable notifications.
    public func setNotifications(_ enabled: Bool, for characteristic: GATTCharacteristic) async throws {
        try await characteristicAccesses.performNotify(for: characteristic.underlyingCharacteristic) {
            cbPeripheral.setNotifyValue(enabled, for: characteristic.underlyingCharacteristic)
        }
    }

    /// Reset all notification values back to `false`.
    ///
    /// Call this when things either go wrong, or you're done with the connection.
    /// This cancels any subscriptions if there are any, or straight disconnects if not.
    /// (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
    private func removeAllNotifications() {
        guard case .connected = cbPeripheral.state else {
            return
        }

        // we need to unsubscribe before we cancel the connection
        for service in cbPeripheral.services ?? [] {
            for characteristic in service.characteristics ?? []  where characteristic.isNotifying {
                cbPeripheral.setNotifyValue(false, for: characteristic)
            }
        }
    }

    /// Write the value of a characteristic expecting a confirmation.
    ///
    /// Writes the value of a characteristic expecting a confirmation from the peripheral.
    ///
    /// - Note: The write operation is specified in Bluetooth Core Specification, Volume 3,
    ///     Part G, 4.9.3 Write Characteristic Value.
    ///
    /// - Parameters:
    ///   - data: The value to write.
    ///   - characteristic: The characteristic to which the value is written.
    /// - Throws: Throws an `CBError` or `CBATTError` if the write fails.
    public func write(data: Data, for characteristic: GATTCharacteristic) async throws {
        try await characteristicAccesses.performWrite(for: characteristic.underlyingCharacteristic) {
            cbPeripheral.writeValue(data, for: characteristic.underlyingCharacteristic, type: .withResponse)
        }
    }

    /// Write the value of a characteristic without expecting a confirmation.
    ///
    /// Writes the value of a characteristic without expecting a confirmation from the peripheral.
    ///
    /// - Note: The write operation is specified in Bluetooth Core Specification, Volume 3,
    ///     Part G, 4.9.1 Write Without Response.
    ///
    /// - Parameters:
    ///   - data: The value to write.
    ///   - characteristic: The characteristic to which the value is written.
    public func writeWithoutResponse(data: Data, for characteristic: GATTCharacteristic) async {
        do {
            try await writeWithoutResponseAccess.perform {
                cbPeripheral.writeValue(data, for: characteristic.underlyingCharacteristic, type: .withoutResponse)
            }
        } catch {
            // task got cancelled, so just throw away the written value
            return
        }
    }

    /// Read the value of a characteristic.
    ///
    /// Read the value for the specified characteristic.
    ///
    /// - Parameter characteristic: The characteristic for which you want to read the value.
    /// - Returns: The value that the peripheral was returned.
    /// - Throws: Throws an `CBError` or `CBATTError` if the read fails.
    public func read(characteristic: GATTCharacteristic) async throws -> Data {
        try await characteristicAccesses.performRead(for: characteristic.underlyingCharacteristic) {
            cbPeripheral.readValue(for: characteristic.underlyingCharacteristic)
        }
    }

    /// Retrieve the current RSSI value.
    ///
    /// Retrieves the current RSSI value for the peripheral while its connected.
    /// - Returns: The read rssi value.
    /// - Throws: Throws an `CBError` or `CBATTError` if the read fails.
    public func readRSSI() async throws -> Int {
        try await rssiAccess.perform {
            cbPeripheral.readRSSI()
        }
    }

    private func synchronizeModel(for service: CBService) {
        let uuid = BTUUID(from: service.uuid)
        guard let gattService = getService(id: uuid) else {
            logger.error("Failed to retrieve service \(service.uuid) of discovered characteristics!")
            return
        }

        // update our model with latest characteristics!
        let changeProtocol = gattService.synchronizeModel()

        for uuid in changeProtocol.removedCharacteristics {
            let locator = CharacteristicLocator(serviceId: uuid, characteristicId: uuid)
            for handler in onChangeHandlers[locator, default: [:]].values {
                if case let .instance(onChange) = handler {
                    onChange(nil) // signal removed characteristic!
                }
            }
        }

        for characteristic in changeProtocol.updatedCharacteristics {
            let locator = CharacteristicLocator(serviceId: uuid, characteristicId: characteristic.id)
            for handler in onChangeHandlers[locator, default: [:]].values {
                if case let .instance(onChange) = handler {
                    onChange(characteristic)
                }
            }
        }
    }

    private func synchronizeModel(for characteristic: CBCharacteristic, capture: GATTCharacteristicCapture) {
        guard let service = characteristic.service,
              let gattCharacteristic = getCharacteristic(id: BTUUID(from: characteristic.uuid), on: BTUUID(from: service.uuid)) else {
            logger.error("Failed to locate GATTCharacteristic for provided one \(characteristic.uuid)")
            return
        }

        gattCharacteristic.synchronizeModel(capture: capture)
    }

    private func invalidateServices(_ ids: Set<BTUUID>) {
        guard storage.services != nil else {
            return
        }

        for id in ids {
            guard let service = storage.services?.removeValue(forKey: id) else {
                continue
            }

            // make sure we notify subscribed handlers about removed services!
            for characteristic in service.characteristics {
                let locator = CharacteristicLocator(serviceId: service.id, characteristicId: characteristic.id)
                for handler in onChangeHandlers[locator, default: [:]].values {
                    if case let .instance(onChange) = handler {
                        onChange(nil) // signal removed characteristic!
                    }
                }
            }
        }
    }

    private func discovered(services: [CBService]) {
        let discoveredIds = Set(services.map { BTUUID(from: $0.uuid) })
        let removedServiceIds = self.storage.services?.keys.filter { uuid in
            !discoveredIds.contains(uuid)
        }

        if let removedServiceIds {
            invalidateServices(Set(removedServiceIds))
        }

        let discoveredServices: [BTUUID: GATTService] = services.reduce(into: [:]) { partialResult, cbService in
            let service = GATTService(service: cbService)
            partialResult[service.id] = service
        }

        if let services = self.storage.services {
            storage.services = services.merging(discoveredServices) { previous, _ in
                previous // just discard service instances that would override previous instance!
            }
        } else {
            storage.services = discoveredServices
        }
    }

    deinit {
        guard let manager else {
            self.logger.warning("Orphaned device \(self.id), \(self.name ?? "unnamed") was de-initialized")
            return
        }

        let id = id
        let name = name

        self.logger.debug("Device \(id), \(name ?? "unnamed") was de-initialized...")

        Task.detached { @Sendable @SpeziBluetooth [storage, nearby] in
            if nearby { // make sure signal is sent
                storage.nearby = false
            }

            manager.handlePeripheralDeinit(id: id)
        }
    }
}


// MARK: Delegate Accessors
extension BluetoothPeripheral {
    private func receivedUpdatedValue(for characteristic: CBCharacteristic, result: Result<Data, Error>) {
        if case let .success(data) = result,
           let service = characteristic.service {
            let locator = CharacteristicLocator(serviceId: BTUUID(from: service.uuid), characteristicId: BTUUID(from: characteristic.uuid))

            for onChange in onChangeHandlers[locator, default: [:]].values {
                guard case let .value(handler) = onChange else {
                    continue
                }
                handler(data)
            }
        }

        characteristicAccesses.resumeRead(with: result, for: characteristic)
    }
}


extension BluetoothPeripheral: Identifiable, Sendable {}


extension BluetoothPeripheral: CustomStringConvertible, CustomDebugStringConvertible {
    public nonisolated var description: String {
        if let name {
            "'\(name)'@\(id)"
        } else {
            "\(id)"
        }
    }

    public nonisolated var debugDescription: String {
        description
    }
}


// MARK: Hashable
extension BluetoothPeripheral: Hashable {
    public nonisolated static func == (lhs: BluetoothPeripheral, rhs: BluetoothPeripheral) -> Bool {
        lhs.id == rhs.id
    }


    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


// MARK: Delegate
extension BluetoothPeripheral {
    private class Delegate: NSObject, CBPeripheralDelegate {
        private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothDeviceDelegate")

        private weak var device: BluetoothPeripheral! // swiftlint:disable:this implicitly_unwrapped_optional

        override init() {
            super.init()
        }


        nonisolated func initDevice(_ device: BluetoothPeripheral) {
            self.device = device
        }

        func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
            guard let device else {
                return
            }

            let name = peripheral.name

            SpeziBluetooth.assumeIsolatedIfAvailableOrTask {
                device.storage.peripheralName = name
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
            guard let device else {
                return
            }

            SpeziBluetooth.assumeIsolatedIfAvailableOrTask {
                let rssi = RSSI.intValue
                device.storage.rssi = rssi

                let result: Result<Int, Error> = error.map { .failure($0) } ?? .success(rssi)
                device.rssiAccess.resume(with: result)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
            guard let device else {
                return
            }

            // this is called if ...
            // 1) The peripheral removes a service from its database.
            // 2) The peripheral adds a new service to its database.
            // 3) The peripheral adds back a previously-removed service, but at a different location in the database.

            // so a service we requested might be gone now. Or might just have changed location.
            // So, discover them to check if they moved location?

            let serviceIds = invalidatedServices.map { BTUUID(from: $0.uuid) }
            logger.debug("Services modified, invalidating \(serviceIds)")

            let peripheral = CBInstance(instantiatedOnDispatchQueue: peripheral)
            SpeziBluetooth.assumeIsolatedIfAvailableOrTask {
                // update our local model!
                device.invalidateServices(Set(serviceIds))

                // make sure we try to rediscover those services though
                peripheral.cbObject.discoverServices(serviceIds.map { $0.cbuuid })
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            guard let device else {
                return
            }

            let cbServices = peripheral.services.map { CBInstance(instantiatedOnDispatchQueue: $0) }
            let result: Result<[BTUUID], Error>

            if let error {
                logger.error("Error discovering services: \(error.localizedDescription)")
                result = .failure(error)
            } else if let services = peripheral.services {
                logger.debug("Successfully discovered services for peripheral \(device): \(services.map { $0.uuid })")
                result = .success(services.map { BTUUID(from: $0.uuid) })
            } else {
                logger.debug("Discovered zero services for peripheral \(device)")
                result = .success([])
            }

            SpeziBluetooth.assumeIsolatedIfAvailableOrTask {
                if let cbServices {
                    device.discovered(services: cbServices.cbObject)
                }

                device.discoverServicesAccess.resume(with: result)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            guard let device else {
                return
            }

            let result: Result<Void, Error>
            if let error {
                logger.error("Error discovering characteristics for service \(service.uuid): \(error.localizedDescription)")
                result = .failure(error)
            } else {
                if let characteristics = service.characteristics, !characteristics.isEmpty {
                    logger.debug("Successfully discovered characteristics for service \(service.uuid): \(characteristics.map { $0.uuid })")
                } else {
                    logger.debug("Discovered zero characteristics for service \(service.uuid)")
                }
                result = .success(())
            }

            let service = CBInstance(instantiatedOnDispatchQueue: service)
            SpeziBluetooth.assumeIsolatedIfAvailableOrTask {
                // update our model with latest characteristics!
                device.synchronizeModel(for: service.cbObject)

                let id = BTUUID(from: service.uuid)
                if let access = device.discoverCharacteristicAccesses[id] {
                    let stillRequired = access.resume(with: result)
                    if !stillRequired { // no one was waiting for discovery on that characteristic, thus we can remove it safely
                        device.discoverCharacteristicAccesses.removeValue(forKey: id)
                    }
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
            guard let device else {
                return
            }

            guard let descriptors = characteristic.descriptors else {
                return
            }

            logger.debug("Discovered descriptors for characteristic \(characteristic.uuid): \(descriptors)")

            let capture = GATTCharacteristicCapture(from: characteristic)
            let characteristic = CBInstance(instantiatedOnDispatchQueue: characteristic)

            SpeziBluetooth.assumeIsolatedIfAvailableOrTask {
                device.synchronizeModel(for: characteristic.cbObject, capture: capture)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            guard let device else {
                return
            }

            let capture = GATTCharacteristicCapture(from: characteristic)
            let characteristic = CBInstance(instantiatedOnDispatchQueue: characteristic)

            SpeziBluetooth.assumeIsolatedIfAvailableOrTask { [logger] in
                // make sure value is propagated beforehand
                device.synchronizeModel(for: characteristic.cbObject, capture: capture)

                if let error {
                    logger.debug("Characteristic read for \(characteristic.uuid) returned with error: \(error)")
                    device.receivedUpdatedValue(for: characteristic.cbObject, result: .failure(error))
                } else if let value = capture.value {
                    device.receivedUpdatedValue(for: characteristic.cbObject, result: .success(value))
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            guard let device else {
                return
            }

            let capture = GATTCharacteristicCapture(from: characteristic)
            let characteristic = CBInstance(instantiatedOnDispatchQueue: characteristic)

            SpeziBluetooth.assumeIsolatedIfAvailableOrTask { [logger] in
                device.synchronizeModel(for: characteristic.cbObject, capture: capture)

                let result: Result<Void, Error>
                if let error {
                    result = .failure(error)
                    logger.warning("Received erroneous write response for \(characteristic.uuid) without an ongoing access: \(error)")
                } else {
                    result = .success(())
                    logger.debug("Characteristic write for \(characteristic.uuid) returned successfully.")
                }

                let didHandle = device.characteristicAccesses.resumeWrite(with: result, for: characteristic.cbObject)
                if !didHandle {
                    logger.warning("Write response for \(characteristic.uuid) was received without an ongoing access!")
                }
            }
        }

        func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
            guard let device else {
                return
            }

            SpeziBluetooth.assumeIsolatedIfAvailableOrTask {
                device.writeWithoutResponseAccess.resume()
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            guard let device else {
                return
            }


            let result: Result<Void, Error>
            if let error {
                logger.error("Error changing notification state for \(characteristic.uuid): \(error)")
                result = .failure(error)
            } else {
                result = .success(())
            }

            let capture = GATTCharacteristicCapture(from: characteristic)
            let characteristic = CBInstance(instantiatedOnDispatchQueue: characteristic)

            SpeziBluetooth.assumeIsolatedIfAvailableOrTask { [logger] in
                device.synchronizeModel(for: characteristic.cbObject, capture: capture)

                if error == nil {
                    if capture.isNotifying {
                        logger.log("Notification began on \(characteristic.uuid)")
                    } else {
                        logger.log("Notification stopped on \(characteristic.uuid).")
                    }
                }

                let didHandle = device.characteristicAccesses.resumeNotify(with: result, for: characteristic.cbObject)
                if !didHandle {
                    logger.warning("Notification state update for \(characteristic.uuid) was received without an ongoing access!")
                }
            }
        }
    }
}

// swiftlint:disable:this file_length
