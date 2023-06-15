////////////////////////////////////////////////////////////////////////////////
//
//  SYMBIOSE
//  Copyright 2020 Symbiose Inc
//  All Rights Reserved.
//
//  NOTICE: This software is proprietary information.
//  Unauthorized use is prohibited.
//
////////////////////////////////////////////////////////////////////////////////

import Foundation

public protocol ErrorLoggerProvider {

    func provide(error: Error?) -> ErrorLogger

}

public class ConsoleLogProvider: ErrorLoggerProvider {

    public func provide(error: Error?) -> ErrorLogger {
        ConsoleErrorLogger()
    }

}

public protocol ErrorLogger {

    func log(_ message: String)

    func flush()

}

class ConsoleErrorLogger: ErrorLogger {

    func log(_ message: String) {
        print(message)
    }

    func flush() {} // Not required for console logger

}
