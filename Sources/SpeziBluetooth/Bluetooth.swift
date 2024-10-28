//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OrderedCollections
import OSLog
@_spi(APISupport)
import Spezi


/// Connect and communicate with Bluetooth devices using modern programming paradigms.
///
/// This module allows to connect and communicate with Bluetooth devices using modern programming paradigms.
/// Under the hood this module uses Apple's [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth)
/// through the ``BluetoothManager``.
///
/// ### Create your Bluetooth device
///
/// The Bluetooth module allows to declarative define your Bluetooth device using a ``BluetoothDevice`` implementation and property wrappers
/// like ``Service`` and ``Characteristic``.
///
/// The below code examples demonstrate how you can implement your own Bluetooth device.
///
/// First of all we define our Bluetooth service by implementing a ``BluetoothService``.
/// We use the ``Characteristic`` property wrapper to declare its characteristics.
/// [`ByteEncodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/byteencodable),
/// [`ByteDecodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/1.0.0/documentation/bytecoding/bytedecodable) or
/// [`ByteCodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/bytecodable) respectively.
///
/// ```swift
/// struct DeviceInformationService: BluetoothService {
///    static let id: BTUUID = "180A"
///
///     @Characteristic(id: "2A29")
///     var manufacturer: String?
///     @Characteristic(id: "2A26")
///     var firmwareRevision: String?
/// }
/// ```
///
/// We can use this Bluetooth service now in the `MyDevice` implementation as follows.
///
/// - Tip: We use the ``DeviceState`` and ``DeviceAction`` property wrappers to get access to the device state and its actions. Those two
///     property wrappers can also be used within a ``BluetoothService`` type.
///
/// ```swift
/// class MyDevice: BluetoothDevice {
///     @DeviceState(\.id)
///     var id: UUID
///     @DeviceState(\.name)
///     var name: String?
///     @DeviceState(\.state)
///     var state: PeripheralState
///
///     @Service var deviceInformation = DeviceInformationService()
///
///     @DeviceAction(\.connect)
///     var connect
///     @DeviceAction(\.disconnect)
///     var disconnect
///
///     required init() {}
/// }
/// ```
///
/// ### Configure the Bluetooth Module
///
/// We use the above `BluetoothDevice` implementation to configure the `Bluetooth` module within the
/// [SpeziAppDelegate](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).
///
/// ```swift
/// import Spezi
///
/// class ExampleDelegate: SpeziAppDelegate {
///     override var configuration: Configuration {
///         Configuration {
///             Bluetooth {
///                 // Define which devices type to discover by what criteria .
///                 // In this case we search for some custom FFF0 service that is advertised.
///                 Discover(MyDevice.self, by: .advertisedService("FFF0"))
///             }
///         }
///     }
/// }
/// ```
///
/// ### Using the Bluetooth Module
///
/// Once you have the `Bluetooth` module configured within your Spezi app, you can access the module within your
/// [`Environment`](https://developer.apple.com/documentation/swiftui/environment).
///
/// You can use the ``SwiftUI/View/scanNearbyDevices(enabled:with:minimumRSSI:advertisementStaleInterval:autoConnect:)``
///  and ``SwiftUI/View/autoConnect(enabled:with:minimumRSSI:advertisementStaleInterval:)``
/// modifiers to scan for nearby devices and/or auto connect to the first available device. Otherwise, you can also manually start and stop scanning for nearby devices
/// using ``scanNearbyDevices(minimumRSSI:advertisementStaleInterval:autoConnect:)`` and ``stopScanning()``.
///
/// To retrieve the list of nearby devices you may use ``nearbyDevices(for:)``.
///
/// > Tip: To easily access the first connected device, you can just query the SwiftUI Environment for your `BluetoothDevice` type.
///     Make sure to declare the property as optional using the respective [`Environment(_:)`](https://developer.apple.com/documentation/swiftui/environment/init(_:)-8slkf)
///     initializer.
///
/// The below code example demonstrates all these steps of retrieving the `Bluetooth` module from the environment, listing all nearby devices,
/// auto connecting to the first one and displaying some basic information of the currently connected device.
///
/// ```swift
/// import SpeziBluetooth
/// import SwiftUI
///
/// struct MyView: View {
///     @Environment(Bluetooth.self)
///     var bluetooth
///     @Environment(MyDevice.self)
///     var myDevice: MyDevice?
///
///     var body: some View {
///         List {
///             if let myDevice {
///                 Section {
///                     Text("Device")
///                     Spacer()
///                     Text("\(myDevice.state.description)")
///                 }
///             }
///
///             Section {
///                 ForEach(bluetooth.nearbyDevices(for: MyDevice.self), id: \.id) { device in
///                     Text("\(device.name ?? "unknown")")
///                 }
///             } header: {
///                 HStack {
///                     Text("Devices")
///                         .padding(.trailing, 10)
///                     if bluetooth.isScanning {
///                         ProgressView()
///                     }
///                 }
///             }
///         }
///             .scanNearbyDevices(with: bluetooth, autoConnect: true)
///     }
/// }
/// ```
///
/// - Tip: Use ``ConnectedDevices`` to retrieve the full list of connected devices from the SwiftUI environment.
///
/// #### Retrieving Devices
///
/// The previous section explained how to discover nearby devices and retrieve the currently connected one from the environment.
/// This is great ad-hoc connection establishment with devices currently nearby.
/// However, this might not be the most efficient approach, if you want to connect to a specific, previously paired device.
/// In these situations you can use the ``retrieveDevice(for:as:)`` method to retrieve a known device.
///
/// Below is a short code example illustrating this method.
///
/// ```swift
/// let id: UUID = ... // a Bluetooth peripheral identifier (e.g., previously retrieved when pairing the device)
///
/// let device = bluetooth.retrieveDevice(for: id, as: MyDevice.self)
///
/// await device.connect() // assume declaration of @DeviceAction(\.connect)
///
/// // Connect doesn't time out. Connection with the device will be established as soon as the device is in reach.
/// ```
///
/// ### Integration with Spezi Modules
///
/// A Spezi [`Module`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module) is a great way of structuring your application into
/// different subsystems and provides extensive capabilities to model relationship and dependence between modules.
/// Every ``BluetoothDevice`` is a `Module`.
/// Therefore, you can easily access your SpeziBluetooth device from within any Spezi `Module` using the standard
/// [Module Dependency](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module-dependency) infrastructure. At the same time,
/// every `BluetoothDevice` can benefit from the same capabilities as every other Spezi `Module`.
///
/// Below is a short code example demonstrating how a `BluetoothDevice` uses the `@Dependency` property to interact with a Spezi Module that is
/// configured within the Spezi application.
///
/// ```swift
/// class Measurements: Module, EnvironmentAccessible, DefaultInitializable {
///     required init() {}
///
///     func recordNewMeasurement(_ measurement: WeightMeasurement) {
///         // ... process measurement
///     }
/// }
///
/// class MyDevice: BluetoothDevice {
///     @Service var weightScale = WeightScaleService()
///
///     // declare dependency to a configured Spezi Module
///     @Dependency var measurements: Measurements
///
///     required init() {}
///
///     func configure() {
///         weightScale.$weightMeasurement.onChange { [weak self] value in
///             self?.handleNewMeasurement(value)
///         }
///     }
///
///     private func handleNewMeasurement(_ measurement: WeightMeasurement) {
///         measurements.recordNewMeasurement(measurement)
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Configure the Bluetooth Module
/// - ``init(_:)``
/// - ``configuration``
///
/// ### Bluetooth State
/// - ``state``
/// - ``isScanning``
/// - ``stateSubscription``
///
/// ### Nearby Devices
/// - ``nearbyDevices(for:)``
/// - ``scanNearbyDevices(minimumRSSI:advertisementStaleInterval:autoConnect:)``
/// - ``stopScanning()``
///
/// ### Retrieve Devices
/// - ``retrieveDevice(for:as:)``
///
/// ### Manually Manage Powered State
/// - ``powerOn()``
/// - ``powerOff()``
@SpeziBluetooth
public final class Bluetooth: Module, EnvironmentAccessible, Sendable {
    @Observable
    class Storage {
        @MainActor var nearbyDevices: OrderedDictionary<UUID, any BluetoothDevice> = [:]

        nonisolated init() {}
    }

    nonisolated static let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "Bluetooth")

    @SpeziBluetooth private let bluetoothManager = BluetoothManager()

    /// The Bluetooth device configuration.
    ///
    /// Set of configured ``BluetoothDevice`` with their corresponding ``DiscoveryCriteria``.
    public nonisolated let configuration: Set<DeviceDiscoveryDescriptor>

    // sadly Swifts "lazy var" won't work here with strict concurrency as it doesn't isolate the underlying lazy storage
    @SpeziBluetooth private var _lazy_discoveryConfiguration: Set<DiscoveryDescription>?
    // swiftlint:disable:previous discouraged_optional_collection identifier_name
    @SpeziBluetooth private var discoveryConfiguration: Set<DiscoveryDescription> {
        guard let discoveryConfiguration = _lazy_discoveryConfiguration else {
            let discovery = configuration.parseDiscoveryDescription()
            self._lazy_discoveryConfiguration = discovery
            return discovery
        }
        return discoveryConfiguration
    }

    @MainActor private let _storage = Storage() // storage for observability


    /// Represents the current state of Bluetooth.
    public nonisolated var state: BluetoothState {
        bluetoothManager.state
    }

    /// Whether or not we are currently scanning for nearby devices.
    public nonisolated var isScanning: Bool {
        bluetoothManager.isScanning
    }


    @MainActor private var nearbyDevices: OrderedDictionary<UUID, any BluetoothDevice> {
        get {
            _storage.nearbyDevices
        }
        set {
            _storage.nearbyDevices = newValue
        }
    }

    /// Subscribe to changes of the `state` property.
    ///
    /// Creates an `AsyncStream` that yields all **future** changes to the ``state`` property.
    public var stateSubscription: AsyncStream<BluetoothState> {
        bluetoothManager.stateSubscription
    }

    /// Dictionary of all initialized devices.
    ///
    /// Devices might be part of `nearbyDevices` as well or just retrieved devices that are eventually connected.
    /// Values are stored weakly. All properties (like `@Characteristic`, `@DeviceState` or `@DeviceAction`) store a reference to `Bluetooth` and report once they are de-initialized
    /// to clear the respective initialized devices from this dictionary.
    private var initializedDevices: OrderedDictionary<UUID, AnyWeakDeviceReference> = [:]

    @Application(\.spezi)
    private var spezi

    private nonisolated var logger: Logger {
        Self.logger
    }

    /// Stores the connected device instance for every configured ``BluetoothDevice`` type.
    @Model @MainActor private var connectedDevicesModel = ConnectedDevicesModel()
    /// Injects the ``BluetoothDevice`` instances from the `ConnectedDevices` model into the SwiftUI environment.
    @Modifier @MainActor private var devicesInjector: ConnectedDevicesEnvironmentModifier


    /// Configure the Bluetooth Module.
    ///
    /// Configures the Bluetooth Module with the provided set of ``DeviceDiscoveryDescriptor``s.
    /// Below is a short code example on how you would discover a `ExampleDevice` by its advertised service id.
    ///
    /// ```swift
    /// Bluetooth {
    ///     Discover(ExampleDevice.self, by: .advertisedService(MyExampleService.self))
    /// }
    /// ```
    ///
    /// - Parameter devices: The set of configured devices.
    @MainActor
    public init(
        @DiscoveryDescriptorBuilder _ devices: @Sendable () -> Set<DeviceDiscoveryDescriptor>
    ) {
        let configuration = devices()
        let deviceTypes = configuration.deviceTypes

        self.configuration = configuration
        self.devicesInjector = ConnectedDevicesEnvironmentModifier(configuredDeviceTypes: deviceTypes)

        Task { @SpeziBluetooth in
            self.observeDiscoveredDevices()
        }
    }

    /// Request to power up the Bluetooth Central.
    ///
    /// This method manually instantiates the underlying Central Manager and ensure that it stays allocated.
    /// Balance this call with a call to ``powerOff()``.
    ///
    /// - Note : The underlying `CBCentralManager` is lazily allocated and deallocated once it isn't needed anymore.
    ///     This is used to delay Bluetooth permission and power prompts to the latest possible moment avoiding unexpected interruptions.
    @SpeziBluetooth
    public func powerOn() {
        bluetoothManager.powerOn()
    }

    /// Request to power down the Bluetooth Central.
    ///
    /// This method request to power off the central. This is delay if the central is still used (e.g., currently scanning or connected peripherals).
    ///
    /// - Note : The underlying `CBCentralManager` is lazily allocated and deallocated once it isn't needed anymore.
    ///     This is used to delay Bluetooth permission and power prompts to the latest possible moment avoiding unexpected interruptions.
    @SpeziBluetooth
    public func powerOff() {
        bluetoothManager.powerOff()
    }

    @SpeziBluetooth
    private func observeDiscoveredDevices() {
        bluetoothManager.onChange(of: \.discoveredPeripherals) { [weak self] discoveredDevices in
            guard let self = self else {
                return
            }

            self.observeDiscoveredDevices()
            self.handleUpdatedNearbyDevicesChange(discoveredDevices)
        }

        // we currently do not track the `retrievedPeripherals` collection of the BluetoothManager. The assumption is that
        // `retrievePeripheral` is always called through the `Bluetooth` module so we are aware of everything anyways.
        // And we don't care about the rest.
    }

    @SpeziBluetooth
    private func handleUpdatedNearbyDevicesChange(_ discoveredDevices: OrderedDictionary<UUID, BluetoothPeripheral>) {
        var newlyPreparedDevices: Set<UUID> = [] // track for which device instances we need to call Spezi/loadModule(...)

        let discoveredDeviceInstances: [UUID: any BluetoothDevice] = discoveredDevices.reduce(into: [:]) { partialResult, entry in
            let device: any BluetoothDevice

            // The union of initializedDevices.keys and discoveredDevices.keys are devices that are connected.
            // Initialized devices might contain additional devices that were removed and discoveredDevices might contain additional
            // that are new.
            if let persistedDevice = initializedDevices[entry.key]?.anyValue {
                device = persistedDevice
            } else {
                let advertisementData = entry.value.advertisementData
                guard let configuration = configuration.find(for: advertisementData, logger: logger) else {
                    logger.warning("Ignoring peripheral \(entry.value) that cannot be mapped to a device class.")
                    return
                }

                // prepareDevice will insert into initializedDevices
                device = prepareDevice(id: entry.key, configuration.deviceType, peripheral: entry.value)
                newlyPreparedDevices.insert(entry.key)
            }

            partialResult[entry.key] = device
        }


        let spezi = spezi
        Task { @MainActor [newlyPreparedDevices] in
            var checkForConnected = false

            // remove all delete keys
            for key in nearbyDevices.keys where discoveredDeviceInstances[key] == nil {
                checkForConnected = true

                nearbyDevices.removeValue(forKey: key)

                // device instances will be automatically deallocated via `notifyDeviceDeinit`
            }

            // add devices for new keys
            for (uuid, device) in discoveredDeviceInstances where nearbyDevices[uuid] == nil {
                checkForConnected = true

                nearbyDevices[uuid] = device

                if newlyPreparedDevices.contains(uuid) {
                    // We load the module with external ownership. Meaning, Spezi won't keep any strong references to the Module and deallocation of
                    // the module is possible, freeing all Spezi related resources.
                    spezi.loadModule(device, ownership: .external)
                }
            }

            if checkForConnected {
                // ensure that we get notified about, e.g., a connected peripheral that is instantly removed
                await handlePeripheralStateChange()
            }
        }
    }


    @_spi(Internal)
    @SpeziBluetooth
    public func _initializedDevicesCount() -> Int { // swiftlint:disable:this identifier_name
        initializedDevices.count
    }

    @SpeziBluetooth
    private func observePeripheralState(of uuid: UUID) {
        // We must make sure that we don't capture the `peripheral` within the `onChange` closure as otherwise
        // this would require a reference cycle within the `BluetoothPeripheral` class.
        // Therefore, we have this indirection via the uuid here.
        guard let peripheral = bluetoothManager.knownPeripherals[uuid] else {
            return
        }

        peripheral.onChange(of: \.state) { [weak self] _ in
            guard let self = self else {
                return
            }

            self.observePeripheralState(of: uuid)
            self.handlePeripheralStateChange()
        }
    }

    @SpeziBluetooth
    private func handlePeripheralStateChange() {
        // check for active connected device
        let connectedDevices = bluetoothManager.knownPeripherals
            .filter { _, value in
                value.state == .connected
            }
            .compactMap { key, _ -> (UUID, any BluetoothDevice)? in
                // initializedDevices might contain devices that are not loaded as a module yet.
                // However, a Task that will load the module will always be scheduled before the @MainActor task below that injects it
                // into the SwiftUI environment.

                // map them to their devices class
                guard let device = initializedDevices[key]?.anyValue else {
                    return nil
                }
                return (key, device)
            }
            .reduce(into: [:]) { result, tuple in
                result[tuple.0] = tuple.1
            }

        Task { @MainActor in
            let connectedDevicesModel = self.connectedDevicesModel
            connectedDevicesModel.update(with: connectedDevices)
        }
    }

    /// Retrieve nearby devices.
    ///
    /// Use this method to retrieve nearby discovered Bluetooth devices. This method will only
    /// return nearby devices that are of the provided ``BluetoothDevice`` type.
    /// - Parameter device: The device type to filter for.
    /// - Returns: A list of nearby devices of a given ``BluetoothDevice`` type.
    @MainActor
    public func nearbyDevices<Device: BluetoothDevice>(for device: Device.Type = Device.self) -> [Device] {
        _storage.nearbyDevices.values.compactMap { device in
            device as? Device
        }
    }


    /// Retrieve a known `BluetoothDevice` by its identifier.
    ///
    /// This method queries the list of known ``BluetoothDevice``s (e.g., paired devices).
    ///
    /// - Tip: You can use this method to connect to a known device. Retrieve the device using this method and use the ``DeviceActions/connect`` action.
    ///     The `connect` action doesn't time out and will make sure to connect to the device once it is available without the need for continuous scanning.
    ///
    /// - Important: Make sure to keep a strong reference to the returned device. The `Bluetooth` module only keeps a weak reference to the device.
    ///     If you don't need the device anymore, ``DeviceActions/disconnect`` and dereference it.
    ///
    /// - Parameters:
    ///   - uuid: The Bluetooth peripheral identifier.
    ///   - device: The device type to use for the peripheral.
    /// - Returns: The retrieved device. Returns nil if the Bluetooth Central could not be powered on (e.g., not authorized) or if no peripheral with the requested identifier was found.
    @SpeziBluetooth
    public func retrieveDevice<Device: BluetoothDevice>(
        for uuid: UUID,
        as device: Device.Type = Device.self
    ) async -> Device? {
        if let anyDevice = initializedDevices[uuid]?.anyValue {
            guard let device = anyDevice as? Device else {
                preconditionFailure("""
                                    Tried to make persistent device for nearby device with differing types. \
                                    Found \(type(of: anyDevice)), requested \(Device.self)
                                    """)
            }
            return device
        }

        // This condition is fine, every device type that wants to be paired has to be discovered at least once.
        // This helps also with building the `ConnectedDevices` statically and have the SwiftUI view hierarchy not re-rendered every time.
        precondition(
            configuration.contains(where: { $0.deviceType == device }),
            "Tried to make persistent device for non-configured device class \(Device.self)"
        )

        let configuration = device.parseDeviceDescription()

        guard let peripheral = await bluetoothManager.retrievePeripheral(for: uuid, with: configuration) else {
            return nil
        }


        let device = prepareDevice(id: uuid, Device.self, peripheral: peripheral)
        // We load the module with external ownership. Meaning, Spezi won't keep any strong references to the Module and deallocation of
        // the module is possible, freeing all Spezi related resources.
        await spezi.loadModule(device, ownership: .external)

        // The semantics of retrievePeripheral is as follows: it returns a BluetoothPeripheral that is weakly allocated by the BluetoothManager.´
        // Therefore, the BluetoothPeripheral is owned by the caller and is automatically deallocated if the caller decides to not require the instance anymore.
        // We want to replicate this behavior with the Bluetooth Module as well, however `BluetoothDevice`s do have reference cycles and require explicit
        // deallocation. Therefore, we introduce this helper RAII structure `PersistentDevice` that equally moves into the ownership of the caller.
        // If they happen to release their reference, the deinit of the class is called informing the Bluetooth Module of de-initialization, allowing us
        // to clean up the underlying BluetoothDevice instance (removing all self references) and therefore allowing to deinit the underlying BluetoothPeripheral.
        return device
    }

    /// Scan for nearby bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``Discover`` declarations provided in the initializer.
    ///
    /// All discovered devices for a given type can be accessed through the ``nearbyDevices(for:)`` method.
    /// The first connected device can be accessed through the
    /// [Environment(_:)](https://developer.apple.com/documentation/swiftui/environment/init(_:)-8slkf) in your SwiftUI view.
    ///
    /// - Tip: Scanning for nearby devices can easily be managed via the ``SwiftUI/View/scanNearbyDevices(enabled:with:minimumRSSI:advertisementStaleInterval:autoConnect:)``
    ///     modifier.
    ///
    /// - Parameters:
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second.
    ///   - autoConnect: If enabled, the bluetooth manager will automatically connect to
    ///     the nearby device if only one is found for a given time threshold.
    @SpeziBluetooth
    public func scanNearbyDevices(
        minimumRSSI: Int? = nil,
        advertisementStaleInterval: TimeInterval? = nil,
        autoConnect: Bool = false
    ) {
        bluetoothManager.scanNearbyDevices(
            discovery: discoveryConfiguration,
            minimumRSSI: minimumRSSI,
            advertisementStaleInterval: advertisementStaleInterval,
            autoConnect: autoConnect
        )
    }

    /// Stop scanning for nearby bluetooth devices.
    @SpeziBluetooth
    public func stopScanning() {
        bluetoothManager.stopScanning()
    }
}


@_spi(APISupport)
extension Bluetooth: BluetoothScanner {
    /// Support for the auto connect modifier.
    @_documentation(visibility: internal)
    public var hasConnectedDevices: Bool {
        bluetoothManager.hasConnectedDevices
    }

    @SpeziBluetooth
    public func scanNearbyDevices(_ state: BluetoothModuleDiscoveryState) {
        scanNearbyDevices(
            minimumRSSI: state.minimumRSSI,
            advertisementStaleInterval: state.advertisementStaleInterval,
            autoConnect: state.autoConnect
        )
    }

    @SpeziBluetooth
    public func updateScanningState(_ state: BluetoothModuleDiscoveryState) {
        let managerState = BluetoothManagerDiscoveryState(
            configuredDevices: discoveryConfiguration,
            minimumRSSI: state.minimumRSSI,
            advertisementStaleInterval: state.advertisementStaleInterval,
            autoConnect: state.autoConnect
        )

        bluetoothManager.updateScanningState(managerState)
    }
}

// MARK: - Device Handling

extension Bluetooth {
    @SpeziBluetooth
    func prepareDevice<Device: BluetoothDevice>(id uuid: UUID, _ device: Device.Type, peripheral: BluetoothPeripheral) -> Device {
        let device = device.init()
        
        let didInjectAnything = device.inject(peripheral: peripheral, using: self)
        if didInjectAnything {
            initializedDevices[uuid] = device.weaklyReference
        } else {
            logger.warning(
                """
                \(Device.self) is an empty device implementation. \
                The same peripheral might be instantiated via multiple \(Device.self) instances if no device property wrappers like
                @Characteristic, @DeviceState or @DeviceAction is used.
                """
            )
        }


        observePeripheralState(of: peripheral.id) // register \.state onChange closure

        
        precondition(!(device is EnvironmentAccessible), "Cannot load BluetoothDevice \(Device.self) that conforms to \(EnvironmentAccessible.self)!")

        return device
    }


    nonisolated func notifyDeviceDeinit(for uuid: UUID) {
        Task { @SpeziBluetooth in
            _notifyDeviceDeinit(for: uuid)
        }
    }


    @SpeziBluetooth
    private func _notifyDeviceDeinit(for uuid: UUID) {
        #if DEBUG || TEST
        Task { @MainActor in
            assert(nearbyDevices[uuid] == nil, "\(#function) was wrongfully called for a device that is still referenced: \(uuid)")
        }
        #endif

        // this clears our weak reference that we use to reuse already created device class once they connect
        let removedEntry = initializedDevices.removeValue(forKey: uuid)

        if let removedEntry {
            logger.debug("\(removedEntry.typeName) device was de-initialized and removed from the Bluetooth module.")
        }
    }
}


extension BluetoothDevice {
    fileprivate var weaklyReference: AnyWeakDeviceReference {
        WeakReference(self)
    }
}

// swiftlint:disable:this file_length
