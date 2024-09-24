//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import AccessorySetupKit


enum DescriptorAspect { // TODO: declare a public enum version that is only avaialble for 18.0 and bridges to this one?
    case name(substring: String) // TODO: just a contains check
    case service(uuid: BTUUID, serviceData: DataDescriptor? = nil)
    case manufacturer(id: ManufacturerIdentifier, manufacturerData: DataDescriptor? = nil)
    case bluetoothRange(Int)
    case supportOptions(UInt)
}


extension DescriptorAspect: Sendable, Hashable {}


// TODO: this should move to the CoreBluetooth model directory, the whole type maybe?
extension DescriptorAspect {
    func matches(name: String?, advertisementData: AdvertisementData) -> Bool { // swiftlint:disable:this cyclomatic_complexity
        switch self {
        case let .name(substring):
            // TODO: allow to match against local name?
            guard let name else {
                return false
            }

            return name.contains(substring)
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
            return true // range doesn't match against advertisement data // TODO: match against Rsii?
        case .supportOptions:
            return true // options doesn't match against advertisement data
        }
    }
}


extension DescriptorAspect: CustomStringConvertible {
    var description: String {
        switch self {
        case let .name(substring):
            ".name(\(substring))"
        case let .service(uuid, serviceData):
            ".service(\(uuid)\(serviceData.map { ", serviceData: \($0.description)" } ?? ""))"
        case let .manufacturer(id, manufacturerData):
            ".manufacturer(\(id)\(manufacturerData.map { ", manufacturerData: \($0.description)" } ?? ""))"
        case let .bluetoothRange(value):
            ".bluetoothRange(\(value))"
        case let .supportOptions(value):
            ".supportOptions(\(value))"
        }
        // TODO: update, enums should be mapped to strings and manufacturer data as well!
    }
}


@available(iOS 18.0, *)
extension DescriptorAspect {
    static func bluetoothRange(_ range: ASDiscoveryDescriptor.Range) -> DescriptorAspect {
        .bluetoothRange(range.rawValue)
    }

    static func supportOptions(_ options: ASAccessory.SupportOptions) -> DescriptorAspect {
        .supportOptions(options.rawValue)
    }

    func apply(to descriptor: ASDiscoveryDescriptor) {
        switch self {
        case let .name(substring):
            descriptor.bluetoothNameSubstring = substring
        case let .service(uuid, serviceData):
            descriptor.bluetoothServiceUUID = uuid.cbuuid
            descriptor.bluetoothServiceDataBlob = serviceData?.data
            descriptor.bluetoothServiceDataMask = serviceData?.mask
        case let .manufacturer(id, manufacturerData):
            descriptor.bluetoothCompanyIdentifier = id.bluetoothCompanyIdentifier
            descriptor.bluetoothManufacturerDataBlob = manufacturerData?.data
            descriptor.bluetoothManufacturerDataMask = manufacturerData?.mask
        case let .bluetoothRange(range):
            guard let range = ASDiscoveryDescriptor.Range(rawValue: range) else {
                preconditionFailure("Failed to construct range from raw value \(range)") // TODO: could also just be a log statement!
            }
            descriptor.bluetoothRange = range
        case let .supportOptions(options):
            descriptor.supportedOptions = .init(rawValue: options)
        }
    }
}
