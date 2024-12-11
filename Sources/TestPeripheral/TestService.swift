//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import OSLog
import SpeziBluetooth
@_spi(TestingSupport)
import SpeziBluetoothServices


struct ATTErrorCode: Error, Sendable {
    let code: CBATTError.Code

    init(_ code: CBATTError.Code) {
        self.code = code
    }
}


@MainActor
@available(visionOS, unavailable)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
final class TestService: Sendable {
    private var logger: Logger {
        Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "TestService")
    }

    private nonisolated(unsafe) weak var peripheral: TestPeripheral?
    let service: CBMutableService

    let eventLog: CBMutableCharacteristic
    /// We only provide the value.
    let readString: CBMutableCharacteristic
    /// We only receive a value.
    let writeString: CBMutableCharacteristic
    /// Bidirectional storage value.
    let readWriteString: CBMutableCharacteristic
    /// Reset peripheral state to default settings
    let reset: CBMutableCharacteristic

    private var readStringCount: UInt = 1
    private var readStringValue: String {
        defer {
            readStringCount += 1
        }
        return "Hello World (\(readStringCount))"
    }

    private var lastEvent: EventLog = .none
    private var readWriteStringValue: String = "Hello Spezi"

    init(peripheral: TestPeripheral) {
        self.peripheral = peripheral
        self.service = CBMutableService(type: BTUUID.testService.cbuuid, primary: true)

        self.eventLog = CBMutableCharacteristic(
            type: BTUUID.eventLogCharacteristic.cbuuid,
            properties: [.indicate, .read],
            value: nil,
            permissions: [.readable]
        )
        self.readString = CBMutableCharacteristic(
            type: BTUUID.readStringCharacteristic.cbuuid,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        self.writeString = CBMutableCharacteristic(
            type: BTUUID.writeStringCharacteristic.cbuuid,
            properties: [.write],
            value: nil,
            permissions: [.writeable]
        )
        self.readWriteString = CBMutableCharacteristic(
            type: BTUUID.readWriteStringCharacteristic.cbuuid,
            properties: [.read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )
        self.reset = CBMutableCharacteristic(type: BTUUID.resetCharacteristic.cbuuid, properties: [.write], value: nil, permissions: [.writeable])

        service.characteristics = [eventLog, readString, writeString, readWriteString, reset]
    }

    @MainActor
    private func resetState() {
        self.readStringCount = 1
        self.readWriteStringValue = "Hello Spezi"
    }


    @MainActor
    func logEvent(_ event: EventLog) async {
        guard let peripheral else {
            logger.error("Couldn't log event with missing peripheral!")
            return
        }

        logger.info("Logging event \(event)")
        self.lastEvent = event
        await peripheral.updateValue(event, for: eventLog)
    }

    @MainActor
    func handleRead(for uuid: BTUUID) -> Result<Data, ATTErrorCode> {
        switch uuid.cbuuid {
        case eventLog.uuid:
            .success(self.lastEvent.encode())
        case writeString.uuid, reset.uuid:
            .failure(.init(.readNotPermitted))
        case readString.uuid:
            .success(readStringValue.encode())
        case readWriteString.uuid:
            .success(readWriteStringValue.encode())
        default:
            .failure(.init(.attributeNotFound))
        }
    }

    @MainActor
    func handleWrite(value: Data?, characteristicId: BTUUID) -> CBATTError.Code {
        guard let value = value else {
            return .attributeNotFound
        }

        switch characteristicId.cbuuid {
        case eventLog.uuid, readString.uuid:
            return .writeNotPermitted
        case writeString.uuid:
            break // we don't store the value anywhere, so we can just discard it :)
        case reset.uuid:
            self.resetState()
        case readWriteString.uuid:
            guard let string = String(data: value) else {
                return .unlikelyError
            }
            readWriteStringValue = string
        default:
            return .attributeNotFound
        }

        return .success
    }
}
