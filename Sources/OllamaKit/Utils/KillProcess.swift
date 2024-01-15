//
//  KillProcess.swift
//
//
//  Created by Sulaiman Ghori on 1/2/24.
//

import Foundation

func killProcessUsingPort(port: Int) {
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
            let killProcess = Process()
            killProcess.executableURL = URL(fileURLWithPath: "/bin/kill")
            killProcess.arguments = ["-9", "\(pid)"]

            print("Killing process \(pid)")
            // Before we do this, make sure it is not our own process
            let ourPid = ProcessInfo.processInfo.processIdentifier
            if pid == ourPid {
                print("Not killing our own process")
                return
            }
            try killProcess.run()
            killProcess.waitUntilExit()
        }
    } catch {
        print("Failed to execute process: \(error)")
    }
}
