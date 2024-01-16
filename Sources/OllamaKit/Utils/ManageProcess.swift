//
//  ManageProcess.swift
//
//
//  Created by Sulaiman Ghori on 1/2/24.
//

import Foundation
import os

private var logger = Logger(subsystem: "OllamaKit", category: "ManageProcess")

func getPID(usingPort port: Int) -> Int? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    process.arguments = ["-i", "tcp:\(port)", "-t"]

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let pidString = String(data: data, encoding: .utf8),
           let pid = Int(pidString.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            return pid
        }
    } catch {
        print("Error getting PID: \(error)")
    }

    return nil
}

func killProcess(usingPort port: Int) -> Bool {
    guard let pid = getPID(usingPort: port) else {
        logger.debug("No process found")
        return false
    }

    let ourPid = ProcessInfo.processInfo.processIdentifier

    if pid == ourPid {
        logger.debug("Not killing our own process")
        return false
    }

    logger.debug("Killing process \(pid)")
    let killProcess = Process()
    killProcess.executableURL = URL(fileURLWithPath: "/bin/kill")
    killProcess.arguments = ["-9", "\(pid)"]

    do {
        try killProcess.run()
        killProcess.waitUntilExit()
        return true
    } catch {
        logger.error("Failed to execute process: \(error)")
        return false
    }
}
