# CoreBluetooth

<!--
#
# This source file is part of the Stanford Spezi open source project
#
# SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
#
# SPDX-License-Identifier: MIT
#
-->

Interact with CoreBluetooth through modern programming language paradigms.

## Overview

[CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) is Apple's framework to interact with Bluetooth and Bluetooth Low-Energy
devices on Apple platforms.
SpeziBluetooth provides easy-to-use mechanisms to perform operations on a Bluetooth central. 

## Topics

### Central

- ``BluetoothManager``
- ``BluetoothState``
- ``BluetoothError``

### Configuration

- ``DiscoveryDescription``
- ``DeviceDescription``
- ``ServiceDescription``
- ``CharacteristicDescription``

### Peripheral

- ``BluetoothPeripheral``
- ``PeripheralState``
- ``GATTService``
- ``GATTCharacteristic``
- ``AdvertisementData``
- ``ManufacturerIdentifier``
- ``WriteType``
- ``BTUUID``
