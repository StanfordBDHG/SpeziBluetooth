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


enum DescriptorAspect {
    /// Matches the ``AdvertisementData/localName``if it is present. If not (and only then) it matches against the GAP name.
    case nameSubstring(String)
    case service(uuid: BTUUID, serviceData: DataDescriptor? = nil)
    case manufacturer(id: ManufacturerIdentifier, manufacturerData: DataDescriptor? = nil)
    case bluetoothRange(Int) // need to store the rawValue to support previous versions
    case supportOptions(UInt) // need to store the rawValue to support previous versions

    var isServiceId: Bool {
        if case .service = self {
            true
        } else {
            false
        }
    }
}


#if canImport(AccessorySetupKit) && !os(macOS)
@available(iOS 18.0, *)
@available(macCatalyst, unavailable)
extension DescriptorAspect {
    static func bluetoothRange(_ range: ASDiscoveryDescriptor.Range) -> DescriptorAspect {
        .bluetoothRange(range.rawValue)
    }

    static func supportOptions(_ options: ASAccessory.SupportOptions) -> DescriptorAspect {
        .supportOptions(options.rawValue)
    }
}
#endif


extension DescriptorAspect: Sendable, Hashable {}


extension DescriptorAspect {
    func matches(name: String?, advertisementData: AdvertisementData) -> Bool { // swiftlint:disable:this cyclomatic_complexity
        switch self {
        case let .nameSubstring(substring):
            // This is (sadly) the behavior of the accessory setup kit.
            // If there is a local name in the advertisement it matches (and only matches!) against the local name.
            // Otherwise, it uses the accessory name.

            return if let localName = advertisementData.localName {
                localName.contains(substring)
            } else if let name {
                name.contains(substring)
            } else {
                false
            }
        case let .service(uuid, serviceData):
            guard advertisementData.serviceUUIDs?.contains(uuid) ?? advertisementData.overflowServiceUUIDs?.contains(uuid) ?? false else {
                return false
            }

            if let serviceData {
                guard let advertisedServiceData = advertisementData.serviceData?[uuid] else {
                    return false
                }
                return serviceData.matches(advertisedServiceData)
            }

            return true
        case let .manufacturer(id, manufacturerData):
            guard let advertisedManufacturerData = advertisementData.manufacturerData,
                  let identifier = ManufacturerIdentifier(data: advertisedManufacturerData) else {
                return false
            }

            guard identifier == id else {
                return false
            }

            if let manufacturerData {
                let suffix = advertisedManufacturerData[2...] // cut await the first two bytes for the manufacturer identifier
                return manufacturerData.matches(suffix)
            }

            return true
        case .bluetoothRange:
            return true // range doesn't match against advertisement data
        case .supportOptions:
            return true // options doesn't match against advertisement data
        }
    }
}


extension DescriptorAspect: CustomStringConvertible {
    var description: String {
        switch self {
        case let .nameSubstring(substring):
            ".name(\(substring))"
        case let .service(uuid, serviceData):
            ".service(\(uuid)\(serviceData.map { ", serviceData: \($0.description)" } ?? ""))"
        case let .manufacturer(id, manufacturerData):
            ".manufacturer(\(id)\(manufacturerData.map { ", manufacturerData: \($0.description)" } ?? ""))"
        case let .bluetoothRange(value):
#if os(iOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 18, *), let range = ASDiscoveryDescriptor.Range(rawValue: value) {
                ".bluetoothRange(\(range))"
            } else {
                ".bluetoothRange(rawValue: \(value))"
            }
#else
            ".bluetoothRange(rawValue: \(value))"
#endif
        case let .supportOptions(value):
#if os(iOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 18, *) {
                ".supportOptions(\(ASAccessory.SupportOptions(rawValue: value)))"
            } else {
                ".supportOptions(rawValue: \(value))"
            }
#else
            ".supportOptions(rawValue: \(value))"
#endif
        }
    }
}
