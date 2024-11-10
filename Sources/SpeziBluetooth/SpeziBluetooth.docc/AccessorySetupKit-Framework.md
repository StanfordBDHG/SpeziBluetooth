# AccessorySetupKit

Integration with Apple's AccessorySetupKit.

<!--
#
# This source file is part of the Stanford Spezi open source project
#
# SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
#
# SPDX-License-Identifier: MIT
#
-->

## Overview

Apple's [AccessorySetupKit](https://developer.apple.com/documentation/accessorysetupkit) enables
privacy-preserving discovery and configuration of accessories.
SpeziBluetooth integrates with

## Topics 


### Interact with AccessorySetupKit

- ``AccessorySetupKit-swift.class``
- ``AccessorySetupKitError``

### Observe Accessory Changes
- ``AccessorySetupKit-swift.class/AccessoryEvent``
- ``AccessoryEventRegistration``

### Discovery Descriptor

Convert a SpeziBluetooth ``DiscoveryCriteria`` into its AccessorySetupKit `ASDiscoveryDescriptor` representation.

- ``DiscoveryCriteria/discoveryDescriptor``
- ``DiscoveryCriteria/matches(descriptor:)``

### Company Identifier

Convert a SpeziBluetooth ``ManufacturerIdentifier`` into its AccessorySetupKit `ASBluetoothCompanyIdentifier` representation.

- ``ManufacturerIdentifier/bluetoothCompanyIdentifier``


### Device Variant Criteria

Apply a SpeziBluetooth ``DeviceVariantCriteria`` to a AccessorySetupKit `ASDiscoveryDescriptor`.

- ``DeviceVariantCriteria/apply(to:)``
- ``DeviceVariantCriteria/matches(descriptor:)``
