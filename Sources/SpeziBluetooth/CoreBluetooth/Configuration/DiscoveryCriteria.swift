//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// The criteria by which we identify a discovered device.
///
/// ## Topics
///
/// ### Criteria
/// - ``advertisedService(_:)-79pid``
/// - ``advertisedService(_:)-5o92s``
/// - ``advertisedServices(_:)-swift.type.method``
/// - ``advertisedServices(_:)-swift.enum.case``
/// - ``advertisedServices(_:_:)``
/// - ``accessory(manufacturer:advertising:)-swift.type.method``
/// - ``accessory(manufacturer:advertising:)-swift.enum.case``
/// - ``accessory(manufacturer:advertising:_:)``
public struct DiscoveryCriteria {
    let aspects: [DescriptorAspect]

    var discoveryIds: [BTUUID] {
        aspects.reduce(into: []) { partialResult, aspect in
            if case let .service(uuid, _) = aspect {
                partialResult.append(uuid)
            }
        }
    }

    func matches(name: String?, advertisementData: AdvertisementData) -> Bool {
        aspects.allSatisfy { aspect in
            aspect.matches(name: name, advertisementData: advertisementData)
        }
    }
}


extension DiscoveryCriteria: Sendable {}


extension DiscoveryCriteria {
    /// Identity a device by their advertised service.
    /// - Parameter uuid: The service uuid the service advertises.
    /// - Returns: A ``DiscoveryCriteria/advertisedServices(_:)-swift.enum.case`` criteria.
    public static func advertisedService(_ uuid: BTUUID, serviceData: DataDescriptor? = nil) -> DiscoveryCriteria {
        DiscoveryCriteria(aspects: [.service(uuid: uuid, serviceData: serviceData)])
    }
    
    /// Identify a device by their advertised services.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameter uuid: The service uuids the service advertises.
    /// - Returns: A ``DiscoveryCriteria/advertisedServices(_:)-swift.enum.case`` criteria.
    public static func advertisedServices(_ uuids: [BTUUID]) -> DiscoveryCriteria {
        DiscoveryCriteria(aspects: uuids.map { uuid in
            .service(uuid: uuid)
        }.reversed())
    }

    /// Identity a device by their advertised service.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameter uuid: The service uuids the service advertises.
    /// - Returns: A ``DiscoveryCriteria/advertisedServices(_:)-swift.enum.case`` criteria.
    public static func advertisedServices(_ uuid: BTUUID...) -> DiscoveryCriteria {
        .advertisedServices(uuid)
    }

    /// Identify a device by their advertised service.
    /// - Parameter service: The service type.
    /// - Returns: A ``DiscoveryCriteria/advertisedServices(_:)-swift.enum.case`` criteria.
    public static func advertisedService<Service: BluetoothService>(
        _ service: Service.Type,
        serviceData: DataDescriptor? = nil
    ) -> DiscoveryCriteria {
        .advertisedService(service.id, serviceData: serviceData)
    }

    /// Identify a device by their advertised services.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - service: The service type.
    ///   - additionalService: An optional parameter pack argument to supply additional service types the accessory is expected to advertise.
    /// - Returns: A ``DiscoveryCriteria/advertisedServices(_:)-swift.enum.case`` criteria.
    public static func advertisedServices<Service: BluetoothService, each S: BluetoothService>(
        _ service: Service.Type,
        _ additionalService: repeat (each S).Type
    ) -> DiscoveryCriteria {
        var serviceIds: [BTUUID] = [service.id]
        repeat serviceIds.append((each additionalService).id)

        return .advertisedServices(serviceIds)
    }
}


import AccessorySetupKit // TODO: update
extension DiscoveryCriteria {
    @available(iOS 18, *)
    public static func accessory(
        advertising uuid: BTUUID, // TODO: typed specification!
        serviceData: DataDescriptor? = nil,
        manufacturer: ManufacturerIdentifier,
        manufacturerData: DataDescriptor? = nil,
        nameSubstring: String? = nil,
        range: ASDiscoveryDescriptor.Range = .default,
        supportOptions: ASAccessory.SupportOptions = [] // TODO: non-iOs 18 variants without these two!
    ) -> DiscoveryCriteria {
        var aspects: [DescriptorAspect] = [
            .service(uuid: uuid, serviceData: serviceData),
            .manufacturer(id: manufacturer, manufacturerData: manufacturerData),
            .bluetoothRange(range),
            .supportOptions(supportOptions)
        ]

        if let nameSubstring {
            aspects.append(.name(substring: nameSubstring)) // TODO: rename!
        }

        return DiscoveryCriteria(aspects: aspects)
    }

    @available(iOS 18, *)
    public static func accessory(
        advertising uuid: BTUUID,
        serviceData: DataDescriptor? = nil,
        manufacturer: ManufacturerIdentifier? = nil,
        nameSubstring: String? = nil,
        range: ASDiscoveryDescriptor.Range = .default,
        supportOptions: ASAccessory.SupportOptions = []
    ) -> DiscoveryCriteria {
        var aspects: [DescriptorAspect] = [
            .service(uuid: uuid, serviceData: serviceData),
            .bluetoothRange(range),
            .supportOptions(supportOptions)
        ]

        if let manufacturer {
            aspects.append(.manufacturer(id: manufacturer))
        }

        if let nameSubstring {
            aspects.append(.name(substring: nameSubstring)) // TODO: rename!
        }

        return DiscoveryCriteria(aspects: aspects)
    }

    /// Identify a device by its manufacturer and advertised services.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - manufacturer: The Bluetooth SIG-assigned manufacturer identifier.
    ///   - uuids: The service uuids the service advertises.
    /// - Returns: A ``DiscoveryCriteria/accessory(manufacturer:advertising:)-swift.enum.case`` criteria.
    public static func accessory(manufacturer: ManufacturerIdentifier, advertising uuids: BTUUID...) -> DiscoveryCriteria {
        .accessory(manufacturer: manufacturer, advertising: uuids)
    }

    /// Identify a device by its manufacturer and advertised services.
    /// 
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - manufacturer: The Bluetooth SIG-assigned manufacturer identifier.
    ///   - uuids: The service uuids the service advertises.
    /// - Returns: A ``DiscoveryCriteria/accessory(manufacturer:advertising:)-swift.enum.case`` criteria.
    public static func accessory(manufacturer: ManufacturerIdentifier, advertising: [BTUUID]) -> DiscoveryCriteria {
        let manufacturer: [DescriptorAspect] = [.manufacturer(id: manufacturer)]
        let serviceIds: [DescriptorAspect] = advertising.map { uuid in
            .service(uuid: uuid)
        }.reversed()

        return DiscoveryCriteria(aspects: manufacturer + serviceIds)
    }

    /// Identify a device by its manufacturer and advertised service.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - manufacturer: The Bluetooth SIG-assigned manufacturer identifier.
    ///   - service: The service type.
    ///   - additionalService: An optional parameter pack argument to supply additional service types the accessory is expected to advertise.
    /// - Returns: A ``DiscoveryCriteria/accessory(manufacturer:advertising:)-swift.enum.case`` criteria.
    public static func accessory<Service: BluetoothService, each S: BluetoothService>( // TODO: accessory without manufacturer?
        manufacturer: ManufacturerIdentifier,
        advertising service: Service.Type,
        _ additionalService: repeat (each S).Type
    ) -> DiscoveryCriteria {
        var serviceIds: [BTUUID] = [service.id]
        repeat serviceIds.append((each additionalService).id)

        return .accessory(manufacturer: manufacturer, advertising: serviceIds)
    }

    // TODO: additional overloads with range?
}


extension DiscoveryCriteria: Hashable, CustomStringConvertible {
    public var description: String {
        "DiscoveryCriteria(\(aspects.map { $0.description }.joined(separator: ", ")))"
    }
}
