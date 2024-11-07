# ``SpeziBluetooth``

<!--
#
# This source file is part of the Stanford Spezi open source project
#
# SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
#
# SPDX-License-Identifier: MIT
#
-->

Connect and communicate with Bluetooth devices using modern programming paradigms.

## Overview

The Spezi Bluetooth module provides a convenient way to handle state management with a Bluetooth device,
retrieve data from different services and characteristics,
and write data to a combination of services and characteristics.

This package uses Apples [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) framework under the hood.

> Tip: You will need a basic understanding of the Bluetooth Terminology and the underlying software model to understand
    the structure and API of the Spezi Bluetooth module. You can find a good overview in the
    [Wikipedia Bluetooth Low Energy (LE) Software Model section](https://en.wikipedia.org/wiki/Bluetooth_Low_Energy#Software_model) or the
    [Developer’s Guide to Bluetooth Technology](https://www.bluetooth.com/blog/a-developers-guide-to-bluetooth/).


## Setup


### Add Spezi Bluetooth as a Dependency

You need to add the Spezi Bluetooth Swift package to
[your app in Xcode](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app#) or
[Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode#Add-a-dependency-on-another-Swift-package).

> Important: If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/initial-setup) to set up the core Spezi infrastructure.


### Register the Module

The ``Bluetooth`` module needs to be registered in a Spezi-based application using the 
[`configuration`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate/configuration) in a
[`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate):
```swift
class ExampleAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth {
                // discover devices ...
            }
        }
    }
}
```

> Tip: You can learn more about a [`Module` in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module).


## Example

### Create your Bluetooth device

The ``Bluetooth`` module allows to declarative define your Bluetooth device using a ``BluetoothDevice`` implementation and property wrappers
like ``Service`` and ``Characteristic``.

The below code examples demonstrate how you can implement your own Bluetooth device.

First of all we define our Bluetooth service by implementing a ``BluetoothService``.
We use the ``Characteristic`` property wrapper to declare its characteristics.
Note that the value types needs to be optional and conform to
[`ByteEncodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/byteencodable),
[`ByteDecodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/1.0.0/documentation/bytecoding/bytedecodable) or
[`ByteCodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/bytecodable) respectively.

```swift
struct DeviceInformationService: BluetoothService {
    static let id: BTUUID = "180A"

    @Characteristic(id: "2A29")
    var manufacturer: String?
    @Characteristic(id: "2A26")
    var firmwareRevision: String?
}
```

We can use this Bluetooth service now in the `MyDevice` implementation as follows.

> Tip: We use the ``DeviceState`` and ``DeviceAction`` property wrappers to get access to the device state and its actions. Those two
    property wrappers can also be used within a ``BluetoothService`` type.

```swift
class MyDevice: BluetoothDevice {
    @DeviceState(\.id)
    var id: UUID
    @DeviceState(\.name)
    var name: String?
    @DeviceState(\.state)
    var state: PeripheralState

    @Service var deviceInformation = DeviceInformationService()

    @DeviceAction(\.connect)
    var connect
    @DeviceAction(\.disconnect)
    var disconnect

    required init() {}
}
```

### Configure the Bluetooth Module

We use the above `BluetoothDevice` implementation to configure the ``Bluetooth`` module within the
[SpeziAppDelegate](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).

```swift
import Spezi

class ExampleDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth {
                // Define which devices type to discover by what criteria .
                // In this case we search for some custom FFF0 characteristic that is advertised.
                Discover(MyDevice.self, by: .advertisedService("FFF0"))
            }
        }
    }
}
```

### Using the Bluetooth Module

Once you have the `Bluetooth` module configured within your Spezi app, you can access the module within your
[`Environment`](https://developer.apple.com/documentation/swiftui/environment).

You can use the ``SwiftUICore/View/scanNearbyDevices(enabled:with:minimumRSSI:advertisementStaleInterval:autoConnect:)``
and ``SwiftUICore/View/autoConnect(enabled:with:minimumRSSI:advertisementStaleInterval:)``
modifiers to scan for nearby devices and/or auto connect to the first available device. Otherwise, you can also manually start and stop scanning for nearby devices
using ``Bluetooth/scanNearbyDevices(minimumRSSI:advertisementStaleInterval:autoConnect:)`` and ``Bluetooth/stopScanning()``.

To retrieve the list of nearby devices you may use ``Bluetooth/nearbyDevices(for:)``.

> Tip: To easily access the first connected device, you can just query the SwiftUI Environment for your `BluetoothDevice` type.
    Make sure to declare the property as optional using the respective [`Environment(_:)`](https://developer.apple.com/documentation/swiftui/environment/init(_:)-8slkf)
    initializer.

The below code example demonstrates all these steps of retrieving the `Bluetooth` module from the environment, listing all nearby devices,
auto connecting to the first one and displaying some basic information of the currently connected device.

```swift
import SpeziBluetooth
import SwiftUI

struct MyView: View {
    @Environment(Bluetooth.self)
    var bluetooth
    @Environment(MyDevice.self)
    var myDevice: MyDevice?

    var body: some View {
        List {
            if let myDevice {
                Section {
                    Text("Device")
                    Spacer()
                    Text("\(myDevice.state.description)")
                }
            }

            Section {
                ForEach(bluetooth.nearbyDevices(for: MyDevice.self), id: \.id) { device in
                    Text("\(device.name ?? "unknown")")
                }
            } header: {
                HStack {
                    Text("Devices")
                        .padding(.trailing, 10)
                    if bluetooth.isScanning {
                        ProgressView()
                    }
                }
            }
        }
            .scanNearbyDevices(with: bluetooth, autoConnect: true)
    }
}
```

> Tip: Use ``ConnectedDevices`` to retrieve the full list of connected devices from the SwiftUI environment.

#### Retrieving Devices

The previous section explained how to discover nearby devices and retrieve the currently connected one from the environment.
This is great ad-hoc connection establishment with devices currently nearby.
However, this might not be the most efficient approach, if you want to connect to a specific, previously paired device.
In these situations you can use the ``Bluetooth/retrieveDevice(for:as:)`` method to retrieve a known device.

Below is a short code example illustrating this method.

```swift
let id: UUID = ... // a Bluetooth peripheral identifier (e.g., previously retrieved when pairing the device)

let device = bluetooth.retrieveDevice(for: id, as: MyDevice.self)

await device.connect() // assume declaration of @DeviceAction(\.connect)

// Connect doesn't time out. Connection with the device will be established as soon as the device is in reach.
```

### Integration with Spezi Modules

A Spezi [`Module`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module) is a great way of structuring your application into
different subsystems and provides extensive capabilities to model relationship and dependence between modules.
Every ``BluetoothDevice`` is a `Module`.
Therefore, you can easily access your SpeziBluetooth device from within any Spezi `Module` using the standard
[Module Dependency](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module-dependency) infrastructure. At the same time,
every `BluetoothDevice` can benefit from the same capabilities as every other Spezi `Module`.

Below is a short code example demonstrating how a `BluetoothDevice` uses the `@Dependency` property to interact with a Spezi Module that is
configured within the Spezi application.

```swift
class Measurements: Module, EnvironmentAccessible, DefaultInitializable {
    required init() {}

    func recordNewMeasurement(_ measurement: WeightMeasurement) {
        // ... process measurement
    }
}

class MyDevice: BluetoothDevice {
    @Service var weightScale = WeightScaleService()
    
    // declare dependency to a configured Spezi Module
    @Dependency var measurements: Measurements
    
    required init() {}

    func configure() {
        weightScale.$weightMeasurement.onChange { [weak self] value in
            self?.handleNewMeasurement(value)
        }
    }
    
    private func handleNewMeasurement(_ measurement: WeightMeasurement) {
        measurements.recordNewMeasurement(measurement)
    }
}
```

### Thread Model

Every instance of ``BluetoothManager`` (or ``Bluetooth``) creates an `SerialExecutor` to dispatch any Bluetooth related action.
All state is manipulated from this executor. This serial executor is shared with `CoreBluetooth` as well.
All ``BluetoothPeripheral`` actors (or your ``BluetoothDevice`` implementation) share the `SerialExecutor` from the respective Bluetooth Manager as well.

Note that this includes all state within your ``Characteristic``, ``Service`` or ``DeviceState`` properties as well.

> Tip: To ensure that values stay consistent over a certain operation (e.g., within a view body) you need to establish those guarantees yourself.

For example, when displaying nearby devices, store the result of ``Bluetooth/nearbyDevices(for:)`` once and use it for all your computation
(e.g., check for non emptiness and then displaying them). Two consecutive calls to ``Bluetooth/nearbyDevices(for:)`` might deliver different results
due to their async nature.

## Topics

### Configuring the Bluetooth Module

- ``Bluetooth``
- ``Discover``
- ``DiscoveryCriteria``

### Discovering nearby devices

- ``SwiftUICore/View/scanNearbyDevices(enabled:with:minimumRSSI:advertisementStaleInterval:autoConnect:)``
- ``SwiftUICore/View/autoConnect(enabled:with:minimumRSSI:advertisementStaleInterval:)``
- ``SwiftUICore/View/bluetoothScanningOptions(minimumRSSI:advertisementStaleInterval:)``
- ``ConnectedDevices``

### Declaring a Bluetooth Device

- ``BluetoothDevice``
- ``BluetoothService``
- ``Service``
- ``Characteristic``
- ``DeviceState``
- ``DeviceAction``

### Concurrency

- ``SpeziBluetooth/SpeziBluetooth``

### Frameworks

- <doc:CoreBluetooth-Framework>
- <doc:AccessorySetupKit-Framework>
