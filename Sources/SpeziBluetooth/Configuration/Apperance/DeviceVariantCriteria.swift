//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation
import SpeziViews


/// Describes the identifying criteria for a device variant.
///
/// For more information refer to ``Variant``.
///
/// ## Topics
///
/// ### Criteria
/// - ``service(_:serviceData:)-8g3u6``
/// - ``service(_:serviceData:)-7fadh``
/// - ``nameSubstring(_:)``
/// - ``manufacturer(_:manufacturerData:)``
///
/// ### Match against discovery information
/// - ``matches(name:advertisementData:)``
public struct DeviceVariantCriteria {
    let aspects: [DescriptorAspect]

    init(_ aspects: [DescriptorAspect]) {
        self.aspects = aspects
    }

    init(_ aspect: DescriptorAspect) {
        self.init([aspect])
    }

    init(from criteria: [DeviceVariantCriteria]) {
        aspects = criteria.flatMap { $0.aspects }
    }
    
    /// Determine if the criteria matches a given device discovery information.
    /// - Parameters:
    ///   - name: The device name. `nil` if not available.
    ///   - advertisementData: The advertisement data of the device.
    /// - Returns: Returns `true` if the criteria matches the device.
    public func matches(name: String?, advertisementData: AdvertisementData) -> Bool {
        aspects.allSatisfy { aspect in
            aspect.matches(name: name, advertisementData: advertisementData)
        }
    }
}


extension DeviceVariantCriteria: Sendable, Hashable {}


extension DeviceVariantCriteria {
    /// Match against the device name.
    ///
    /// If there is a ``AdvertisementData/localName`` present in the advertisement, the name substring matches against the advertisement name.
    /// If the localName is not present (any only then), the substring is matched against the GAP device name.
    /// - Parameter substring: The name substring that has to be part of the advertised name.
    /// - Returns: Returns the `DeviceVariantCriteria`.
    public static func nameSubstring(_ substring: String) -> DeviceVariantCriteria {
        DeviceVariantCriteria(.nameSubstring(substring))
    }
    
    /// Match against a advertised service.
    /// - Parameters:
    ///   - uuid: The service uuid.
    ///   - serviceData: Optional service data that has to be advertised.
    /// - Returns: Returns the `DeviceVariantCriteria`.
    public static func service(_ uuid: BTUUID, serviceData: DataDescriptor? = nil) -> DeviceVariantCriteria {
        DeviceVariantCriteria(.service(uuid: uuid, serviceData: serviceData))
    }
    
    /// Match against a advertised service.
    /// - Parameters:
    ///   - service: The service type.
    ///   - serviceData: Optional service data that has to be advertised.
    /// - Returns: Returns the `DeviceVariantCriteria`.
    public static func service<Service: BluetoothService>(_ service: Service.Type, serviceData: DataDescriptor? = nil) -> DeviceVariantCriteria {
        .service(service.id, serviceData: serviceData)
    }
    
    /// Match against advertised manufacturer information.
    /// - Parameters:
    ///   - id: The manufacturer identifier.
    ///   - manufacturerData: Optional manufacturer data that has to be advertised.
    /// - Returns: Returns the `DeviceVariantCriteria`.
    public static func manufacturer(_ id: ManufacturerIdentifier, manufacturerData: DataDescriptor? = nil) -> DeviceVariantCriteria {
        DeviceVariantCriteria(.manufacturer(id: id, manufacturerData: manufacturerData))
    }
}
