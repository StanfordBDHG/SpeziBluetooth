//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog


/// The description for a certain type of device.
///
/// Describes what services we expect to be present for a certain type of device.
/// The ``BluetoothManager`` uses that to determine what devices to discover and what services and characteristics to expect.
public struct DeviceDescription {
    /// The set of service configurations we expect from the device.
    ///
    /// This will be the list of services we are interested in and we try to discover.
    /// - Note: If `nil`, we discover all services on a device.
    public var services: Set<ServiceDescription>? { // swiftlint:disable:this discouraged_optional_collection
        let values: Dictionary<BTUUID, ServiceDescription>.Values? = _services?.values
        return values.map { Set($0) }
    }

    private let _services: [BTUUID: ServiceDescription]?  // swiftlint:disable:this discouraged_optional_collection

    /// Create a new device description.
    /// - Parameter services: The set of service descriptions specifying the expected services.
    public init(services: Set<ServiceDescription>? = nil) {
        // swiftlint:disable:previous discouraged_optional_collection
        self._services = services?.reduce(into: [:]) { partialResult, description in
            partialResult[description.serviceId] = description
        }
    }


    /// Retrieve the service description for a given service id.
    /// - Parameter serviceId: The Bluetooth service id.
    /// - Returns: Returns the service description if present.
    public func description(for serviceId: BTUUID) -> ServiceDescription? {
        _services?[serviceId]
    }
}


extension DeviceDescription: Sendable {}


extension DeviceDescription: Hashable {}


extension Collection where Element: Identifiable, Element.ID == DiscoveryCriteria {
    func find(name: String?, advertisementData: AdvertisementData, logger: Logger) -> Element? {
        let configurations = filter { configuration in
            configuration.id.matches(name: name, advertisementData: advertisementData)
        }

        if configurations.count > 1 {
            logger.warning(
                """
                Found ambiguous discovery configuration for peripheral. Using for of all matched criteria: \
                \(configurations.map { $0.id.description }.joined(separator: ", "))
                """
            )
        }

        return configurations.first
    }
}
