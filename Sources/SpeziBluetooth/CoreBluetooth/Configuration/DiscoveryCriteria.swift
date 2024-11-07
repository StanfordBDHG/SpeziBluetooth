//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(AccessorySetupKit) && !os(macOS)
import AccessorySetupKit
#endif
import SpeziFoundation


/// The criteria by which we identify a discovered device.
///
/// ## Topics
///
/// ### Discovery by Service Type
/// - ``advertisedService(_:serviceData:)-446yf``
/// - ``advertisedServices(_:_:)``
///
/// ### Discovery by Service UUID
///
/// - ``advertisedService(_:serviceData:)-7ye2y``
/// - ``advertisedServices(_:)-2ymt0``
/// - ``advertisedServices(_:)-1s760``
///
/// ### Discovery an Accessory by Service Type
/// - ``accessory(advertising:serviceData:nameSubstring:)-2uola``
/// - ``accessory(advertising:serviceData:manufacturer:manufacturerData:nameSubstring:)-4xehl``
/// - ``accessory(advertising:serviceData:nameSubstring:range:supportOptions:)-z6kr``
/// - ``accessory(advertising:serviceData:manufacturer:manufacturerData:nameSubstring:range:supportOptions:)-5yvyv``
///
/// ### Discovery an Accessory by Service UUID
///
/// - ``accessory(advertising:serviceData:nameSubstring:)-5rzd3``
/// - ``accessory(advertising:serviceData:manufacturer:manufacturerData:nameSubstring:)-7zwso``
/// - ``accessory(advertising:serviceData:nameSubstring:range:supportOptions:)-61h91``
/// - ``accessory(advertising:serviceData:manufacturer:manufacturerData:nameSubstring:range:supportOptions:)-5gotr``
///
/// ### Discovery an Accessory that advertise multiple Services
/// - ``accessory(manufacturer:manufacturerData:nameSubstring:advertising:)-5xdh2``
/// - ``accessory(manufacturer:manufacturerData:nameSubstring:advertising:)-1j9zn``
/// - ``accessory(manufacturer:manufacturerData:nameSubstring:advertising:_:)``
public struct DiscoveryCriteria {
    let aspects: [DescriptorAspect]

    var discoveryIds: [BTUUID] {
        aspects.reduce(into: []) { partialResult, aspect in
            if case let .service(uuid, _) = aspect {
                partialResult.append(uuid)
            }
        }
    }

    init(_ aspects: [DescriptorAspect]) {
        self.aspects = aspects
    }

    init(_ aspect: DescriptorAspect) {
        self.aspects = [aspect]
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
    /// - Parameters:
    ///   - uuid: The service uuid the service advertises.
    ///   - serviceData: The optional data descriptor for the service data that the device has to advertise.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func advertisedService(_ uuid: BTUUID, serviceData: DataDescriptor? = nil) -> DiscoveryCriteria {
        DiscoveryCriteria(.service(uuid: uuid, serviceData: serviceData))
    }
    
    /// Identify a device by their advertised services.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameter uuids: The service uuids the service advertises.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func advertisedServices(_ uuids: [BTUUID]) -> DiscoveryCriteria {
        // we reverse the internal representation to make sure that the first uuid is used with the ASDiscoveryDescriptor
        DiscoveryCriteria(uuids.map { .service(uuid: $0) }.reversed())
    }

    /// Identity a device by their advertised service.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameter uuid: The service uuids the service advertises.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func advertisedServices(_ uuid: BTUUID...) -> DiscoveryCriteria {
        .advertisedServices(uuid)
    }

    /// Identify a device by their advertised service.
    /// - Parameters:
    ///   - service: The service type.
    ///   - serviceData: The optional data descriptor for the service data that the device has to advertise.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
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
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func advertisedServices<Service: BluetoothService, each S: BluetoothService>(
        _ service: Service.Type,
        _ additionalService: repeat (each S).Type
    ) -> DiscoveryCriteria {
        var serviceIds: [BTUUID] = [service.id]
        repeat serviceIds.append((each additionalService).id)

        return .advertisedServices(serviceIds)
    }
}


extension DiscoveryCriteria {
    private static func accessory(
        uuid: BTUUID,
        serviceData: DataDescriptor? = nil,
        manufacturer: ManufacturerIdentifier? = nil,
        manufacturerData: DataDescriptor? = nil,
        nameSubstring: String? = nil,
        range: Int? = nil,
        supportOptions: UInt? = nil
    ) -> DiscoveryCriteria {
        var aspects: [DescriptorAspect] = [
            .service(uuid: uuid, serviceData: serviceData)
        ]

        if let manufacturer {
            aspects.append(.manufacturer(id: manufacturer, manufacturerData: manufacturerData))
        }

        if let nameSubstring {
            aspects.append(.nameSubstring(nameSubstring))
        }

        if let range {
            aspects.append(.bluetoothRange(range))
        }

        if let supportOptions {
            aspects.append(.supportOptions(supportOptions))
        }

        return DiscoveryCriteria(aspects)
    }
    
    /// Identify an accessory by its service, manufacturer and name.
    /// - Parameters:
    ///   - uuid: The service uuid that the accessory advertises.
    ///   - serviceData: An optional data descriptor that matches against the service data advertised for the given service uuid.
    ///   - manufacturer: The manufacturer identifier the accessory has to advertise.
    ///   - manufacturerData: An optional data descriptor that matches against the rest of the manufacturer data.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func accessory( // swiftlint:disable:this function_default_parameter_at_end
        advertising uuid: BTUUID,
        serviceData: DataDescriptor? = nil,
        manufacturer: ManufacturerIdentifier,
        manufacturerData: DataDescriptor? = nil,
        nameSubstring: String? = nil
    ) -> DiscoveryCriteria {
        .accessory(
            uuid: uuid,
            serviceData: serviceData,
            manufacturer: manufacturer,
            manufacturerData: manufacturerData,
            nameSubstring: nameSubstring
        )
    }
    
    /// Identify an accessory by its service and name.
    /// - Parameters:
    ///   - uuid: The service uuid that the accessory advertises.
    ///   - serviceData: An optional data descriptor that matches against the service data advertised for the given service uuid.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func accessory(
        advertising uuid: BTUUID,
        serviceData: DataDescriptor? = nil,
        nameSubstring: String? = nil
    ) -> DiscoveryCriteria {
        .accessory(
            uuid: uuid,
            serviceData: serviceData,
            nameSubstring: nameSubstring
        )
    }
    
    /// Identify an accessory by its service, manufacturer and name.
    /// - Parameters:
    ///   - service: The service type that the accessory advertises.
    ///   - serviceData: An optional data descriptor that matches against the service data advertised for the given service uuid.
    ///   - manufacturer: The manufacturer identifier the accessory has to advertise.
    ///   - manufacturerData: An optional data descriptor that matches against the rest of the manufacturer data.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func accessory<Service: BluetoothService>( // swiftlint:disable:this function_default_parameter_at_end
        advertising service: Service.Type,
        serviceData: DataDescriptor? = nil,
        manufacturer: ManufacturerIdentifier,
        manufacturerData: DataDescriptor? = nil,
        nameSubstring: String? = nil
    ) -> DiscoveryCriteria {
        .accessory(
            uuid: service.id,
            serviceData: serviceData,
            manufacturer: manufacturer,
            manufacturerData: manufacturerData,
            nameSubstring: nameSubstring
        )
    }

    /// Identify an accessory by its service and name.
    /// - Parameters:
    ///   - service: The service type that the accessory advertises.
    ///   - serviceData: An optional data descriptor that matches against the service data advertised for the given service uuid.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func accessory<Service: BluetoothService>(
        advertising service: Service.Type,
        serviceData: DataDescriptor? = nil,
        nameSubstring: String? = nil
    ) -> DiscoveryCriteria {
        .accessory(
            uuid: service.id,
            serviceData: serviceData,
            nameSubstring: nameSubstring
        )
    }

#if canImport(AccessorySetupKit) && !os(macOS)
    /// Identify an accessory by its service, manufacturer and name with additional options for the AccessorySetupKit.
    /// - Parameters:
    ///   - uuid: The service uuid that the accessory advertises.
    ///   - serviceData: An optional data descriptor that matches against the service data advertised for the given service uuid.
    ///   - manufacturer: The manufacturer identifier the accessory has to advertise.
    ///   - manufacturerData: An optional data descriptor that matches against the rest of the manufacturer data.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    ///   - range: A discovery range that is used with the AccessorySetupKit.
    ///   - supportOptions: Additional accessory support options which are used with the AccessorySetupKit.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    @available(iOS 18, *)
    @available(macCatalyst, unavailable)
    public static func accessory( // swiftlint:disable:this function_default_parameter_at_end
        advertising uuid: BTUUID,
        serviceData: DataDescriptor? = nil,
        manufacturer: ManufacturerIdentifier,
        manufacturerData: DataDescriptor? = nil,
        nameSubstring: String? = nil,
        range: ASDiscoveryDescriptor.Range = .default,
        supportOptions: ASAccessory.SupportOptions = []
    ) -> DiscoveryCriteria {
        .accessory(
            uuid: uuid,
            serviceData: serviceData,
            manufacturer: manufacturer,
            manufacturerData: manufacturerData,
            nameSubstring: nameSubstring,
            range: range.rawValue,
            supportOptions: supportOptions.rawValue
        )
    }

    /// Identify an accessory by its service and name with additional options for the AccessorySetupKit.
    /// - Parameters:
    ///   - uuid: The service uuid that the accessory advertises.
    ///   - serviceData: An optional data descriptor that matches against the service data advertised for the given service uuid.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    ///   - range: A discovery range that is used with the AccessorySetupKit.
    ///   - supportOptions: Additional accessory support options which are used with the AccessorySetupKit.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    @available(iOS 18, *)
    @available(macCatalyst, unavailable)
    public static func accessory(
        advertising uuid: BTUUID,
        serviceData: DataDescriptor? = nil,
        nameSubstring: String? = nil,
        range: ASDiscoveryDescriptor.Range = .default,
        supportOptions: ASAccessory.SupportOptions = []
    ) -> DiscoveryCriteria {
        .accessory(
            uuid: uuid,
            serviceData: serviceData,
            nameSubstring: nameSubstring,
            range: range.rawValue,
            supportOptions: supportOptions.rawValue
        )
    }

    /// Identify an accessory by its service, manufacturer and name with additional options for the AccessorySetupKit.
    /// - Parameters:
    ///   - service: The service type that the accessory advertises.
    ///   - serviceData: An optional data descriptor that matches against the service data advertised for the given service uuid.
    ///   - manufacturer: The manufacturer identifier the accessory has to advertise.
    ///   - manufacturerData: An optional data descriptor that matches against the rest of the manufacturer data.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    ///   - range: A discovery range that is used with the AccessorySetupKit.
    ///   - supportOptions: Additional accessory support options which are used with the AccessorySetupKit.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    @available(iOS 18, *)
    @available(macCatalyst, unavailable)
    public static func accessory<Service: BluetoothService>( // swiftlint:disable:this function_default_parameter_at_end
        advertising service: Service.Type,
        serviceData: DataDescriptor? = nil,
        manufacturer: ManufacturerIdentifier,
        manufacturerData: DataDescriptor? = nil,
        nameSubstring: String? = nil,
        range: ASDiscoveryDescriptor.Range = .default,
        supportOptions: ASAccessory.SupportOptions = []
    ) -> DiscoveryCriteria {
        .accessory(
            uuid: service.id,
            serviceData: serviceData,
            manufacturer: manufacturer,
            manufacturerData: manufacturerData,
            nameSubstring: nameSubstring,
            range: range.rawValue,
            supportOptions: supportOptions.rawValue
        )
    }

    /// Identify an accessory by its service and name with additional options for the AccessorySetupKit.
    /// - Parameters:
    ///   - service: The service type that the accessory advertises.
    ///   - serviceData: An optional data descriptor that matches against the service data advertised for the given service uuid.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    ///   - range: A discovery range that is used with the AccessorySetupKit.
    ///   - supportOptions: Additional accessory support options which are used with the AccessorySetupKit.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    @available(iOS 18, *)
    @available(macCatalyst, unavailable)
    public static func accessory<Service: BluetoothService>(
        advertising service: Service.Type,
        serviceData: DataDescriptor? = nil,
        nameSubstring: String? = nil,
        range: ASDiscoveryDescriptor.Range = .default,
        supportOptions: ASAccessory.SupportOptions = []
    ) -> DiscoveryCriteria {
        .accessory(
            uuid: service.id,
            serviceData: serviceData,
            nameSubstring: nameSubstring,
            range: range.rawValue,
            supportOptions: supportOptions.rawValue
        )
    }
#endif

    /// Identify a device by its manufacturer and advertised services.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - manufacturer: The Bluetooth SIG-assigned manufacturer identifier.
    ///   - manufacturerData: An optional data descriptor that matches against the rest of the manufacturer data.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    ///   - uuids: The service uuids the service advertises.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func accessory( // swiftlint:disable:this function_default_parameter_at_end
        manufacturer: ManufacturerIdentifier,
        manufacturerData: DataDescriptor? = nil,
        nameSubstring: String? = nil,
        advertising uuids: BTUUID...
    ) -> DiscoveryCriteria {
        .accessory(manufacturer: manufacturer, manufacturerData: manufacturerData, nameSubstring: nameSubstring, advertising: uuids)
    }

    /// Identify a device by its manufacturer and advertised services.
    /// 
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - manufacturer: The Bluetooth SIG-assigned manufacturer identifier.
    ///   - manufacturerData: An optional data descriptor that matches against the rest of the manufacturer data.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    ///   - uuids: The service uuids the service advertises.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func accessory( // swiftlint:disable:this function_default_parameter_at_end
        manufacturer: ManufacturerIdentifier,
        manufacturerData: DataDescriptor? = nil,
        nameSubstring: String? = nil,
        advertising uuids: [BTUUID]
    ) -> DiscoveryCriteria {
        var aspects: [DescriptorAspect] = uuids.map { .service(uuid: $0) }.reversed()

        aspects.append(.manufacturer(id: manufacturer, manufacturerData: manufacturerData))

        if let nameSubstring {
            aspects.append(.nameSubstring(nameSubstring))
        }

        return DiscoveryCriteria(aspects)
    }

    /// Identify a device by its manufacturer and advertised service.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - manufacturer: The Bluetooth SIG-assigned manufacturer identifier.
    ///   - manufacturerData: An optional data descriptor that matches against the rest of the manufacturer data.
    ///   - nameSubstring: Require a given string to be present in the accessory name.
    ///         The substring is matched against the ``AdvertisementData/localName`` if it is present.
    ///         If it is not present, the substring will be matched against the GAP device name.
    ///   - service: The service type.
    ///   - additionalService: An optional parameter pack argument to supply additional service types the accessory is expected to advertise.
    /// - Returns: The `DiscoveryCriteria` identifying an accessory with the specified criteria.
    public static func accessory<Service: BluetoothService, each S: BluetoothService>( // swiftlint:disable:this function_default_parameter_at_end
        manufacturer: ManufacturerIdentifier,
        manufacturerData: DataDescriptor? = nil,
        nameSubstring: String? = nil,
        advertising service: Service.Type,
        _ additionalService: repeat (each S).Type
    ) -> DiscoveryCriteria {
        var serviceIds: [BTUUID] = [service.id]
        repeat serviceIds.append((each additionalService).id)

        return .accessory(manufacturer: manufacturer, manufacturerData: manufacturerData, nameSubstring: nameSubstring, advertising: serviceIds)
    }
}


extension DiscoveryCriteria: Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "DiscoveryCriteria(\(aspects.map { $0.description }.joined(separator: ", ")))"
    }

    public var debugDescription: String {
        description
    }
}
