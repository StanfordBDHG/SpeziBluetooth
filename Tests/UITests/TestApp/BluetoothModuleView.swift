//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import SpeziBluetooth
import SwiftUI


struct BluetoothModuleView: View {
    @Environment(Bluetooth.self)
    private var bluetooth
    @Environment(TestDevice.self)
    private var device: TestDevice?

    var body: some View {
        List { // swiftlint:disable:this closure_body_length
            Section("State") {
                HStack {
                    Text("Scanning")
                    Spacer()
                    Text(bluetooth.isScanning ? "Yes" : "No")
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                HStack {
                    Text("State")
                    Spacer()
                    Text(bluetooth.state.description)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            let nearbyDevices = bluetooth.nearbyDevices(for: TestDevice.self)

            if nearbyDevices.isEmpty {
                SearchingNearbyDevicesView()
            } else {
                Section {
                    ForEach(nearbyDevices) { device in
                        DeviceRowView(peripheral: device)
                    }
                } header: {
                    DevicesHeader(loading: bluetooth.isScanning)
                }
            }

            if let device {
                Section {
                    Text("Device State: \(device.state.description)")
                    Text("RSSI: \(device.rssi)")
                    if let serialNumber = device.deviceInformation.serialNumber {
                        Text("Serial Number: \(serialNumber)")
                    }
                    Button("Query Device Info") {
                        Task {
                            print("Querying ...")
                            do {
                                try await device.deviceInformation.retrieveDeviceInformation()
                                print("Successfully retrieved")
                            } catch {
                                print("Failed with: \(error)")
                            }
                        }
                    }
                }
            }
        }
            .scanNearbyDevices(with: bluetooth, autoConnect: true)
            .navigationTitle("Auto Connect Device")
    }
}


#Preview {
    NavigationStack {
        BluetoothManagerView()
            .previewWith {
                Bluetooth {
                    Discover(TestDevice.self, by: .advertisedService("FFF0"))
                }
            }
    }
}
