//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(AccessorySetupKit) && !os(macOS)
import AccessorySetupKit
import SpeziFoundation


@available(iOS 18.0, *)
@available(macCatalyst, unavailable)
extension DescriptorAspect {
    func apply(to descriptor: ASDiscoveryDescriptor) {
        switch self {
        case let .nameSubstring(substring):
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
                preconditionFailure("Inconsistent state. ASDiscoveryDescriptor.Range could not be reconstructed from rawValue \(range)")
            }
            descriptor.bluetoothRange = range
        case let .supportOptions(options):
            descriptor.supportedOptions = .init(rawValue: options)
        }
    }

    func matches(_ descriptor: ASDiscoveryDescriptor) -> Bool {
        switch self {
        case let .nameSubstring(substring):
            descriptor.bluetoothNameSubstring == substring
        case let .service(uuid, serviceData):
            if let serviceData {
                serviceData == DataDescriptor(
                    dataProperty: descriptor.bluetoothServiceDataBlob,
                    maskProperty: descriptor.bluetoothServiceDataMask
                )
                    && descriptor.bluetoothServiceUUID == uuid.cbuuid
            } else {
                descriptor.bluetoothServiceUUID == uuid.cbuuid
            }
        case let .manufacturer(id, manufacturerData):
            if let manufacturerData {
                manufacturerData == DataDescriptor(
                    dataProperty: descriptor.bluetoothManufacturerDataBlob,
                    maskProperty: descriptor.bluetoothManufacturerDataMask
                )
                    && descriptor.bluetoothCompanyIdentifier == id.bluetoothCompanyIdentifier
            } else {
                descriptor.bluetoothCompanyIdentifier == id.bluetoothCompanyIdentifier
            }
        case let .bluetoothRange(value):
            descriptor.bluetoothRange.rawValue == value
        case let .supportOptions(value):
            descriptor.supportedOptions.contains(ASAccessory.SupportOptions(rawValue: value))
        }
    }
}


extension DataDescriptor {
    fileprivate init?(dataProperty: Data?, maskProperty: Data?) {
        guard let dataProperty, let maskProperty, dataProperty.count == maskProperty.count else {
            return nil
        }
        self.init(data: dataProperty, mask: maskProperty)
    }
}
#endif
