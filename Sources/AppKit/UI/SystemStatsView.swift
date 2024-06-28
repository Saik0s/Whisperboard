// Taken from https://github.com/argmaxinc/swift-system-stats/blob/main/SystemStats/StatisticsView.swift

import Charts
import Combine
import MachO
import os
import SwiftUI

// MARK: - MemoryStat

struct MemoryStat: Identifiable {
  let id = UUID()
  let category: String
  let value: Double
  let timestamp: Date
}

// MARK: - StatisticsView

struct StatisticsView: View {
  @State private var memoryStats: [MemoryStat] = []

  @State private var totalDeviceMemoryBytes: Double = 0.0
  @State private var physicalMemoryBytes: Double = 0.0
  @State private var wiredBytes: Double = 0.0
  @State private var freeBytes: Double = 0.0
  @State private var activeBytes: Double = 0.0
  @State private var inactiveBytes: Double = 0.0
  @State private var compressedBytes: Double = 0.0
  @State private var sumBytes: Double = 0.0
  @State private var appAvailableBytes: Double = 0.0
  @State private var appUnavailableBytes: Double = 0.0

  @State private var batteryLevel: Float = 0.0
  @State private var batteryState: UIDevice.BatteryState = .unknown

  @State private var cpuUsage: Double = 0.0
  @State private var userCPUUsage: Double = 0.0
  @State private var systemCPUUsage: Double = 0.0
  @State private var idleCPUUsage: Double = 0.0
  @State private var niceCPUUsage: Double = 0.0
  @State private var lastCPUInfo: host_cpu_load_info?

  @State private var activeProcessors: Int = 0
  @State private var totalProcessors: Int = 0

  @State private var totalDiskSpace: Double = 0.0
  @State private var usedDiskSpace: Double = 0.0
  @State private var freeDiskSpace: Double = 0.0

  @State private var thermalState: String = "Calculating..."
  @State private var totalUptime: String = "Calculating..."
  @State private var osVersion: String = "Calculating..."
  @State private var phoneModel: String = "Calculating..."
  @State private var uniqueString: String = "Calculating..."
  @State private var deviceType: String = "Calculating..."

  @State private var showTotalMemory = false

  let timer = Timer.publish(every: 1.00001, on: .main, in: .common).autoconnect()

  var body: some View {
    NavigationView {
      List {
        Section(header: Text("Memory Chart")) {
          Chart {
            ForEach(memoryStats, id: \.timestamp) { stat in
              LineMark(
                x: .value("Timestamp", stat.timestamp, unit: .second),
                y: .value("Bytes", stat.value)
              )
              .foregroundStyle(by: .value("Type", stat.category))
              .interpolationMethod(.cardinal)
            }
            if showTotalMemory {
              RuleMark(
                y: .value("Total", totalDeviceMemoryBytes)
              )
              .lineStyle(StrokeStyle(lineWidth: 2))
              .foregroundStyle(.red)
            }
          }
          .chartForegroundStyleScale([
            "Free": .green, "Active": .blue, "Inactive": .orange, "Wired": .purple, "Compressed": .red,
          ])
          .chartXAxis {
            AxisMarks(preset: .aligned, position: .bottom)
          }
          .chartYAxis {
            AxisMarks(preset: .aligned, position: .trailing) { value in
              AxisGridLine()

              let bytesValue = value.as(Double.self) ?? 0.0
              let formattedValue = formattedBytes(bytesValue)
              AxisValueLabel(formattedValue)
            }
          }
          .frame(height: 300)

          Toggle("Show Total", isOn: $showTotalMemory.animation())
        }

        Section(header: Text("Memory Information")) {
          HStack {
            Text("Free")
            Spacer()
            Text(formattedBytes(freeBytes))
          }
          HStack {
            Text("Active")
            Spacer()
            Text(formattedBytes(activeBytes))
          }
          HStack {
            Text("Inactive")
            Spacer()
            Text(formattedBytes(inactiveBytes))
          }
          HStack {
            Text("Wired")
            Spacer()
            Text(formattedBytes(wiredBytes))
          }
          HStack {
            Text("Compressed")
            Spacer()
            Text(formattedBytes(compressedBytes))
          }
          HStack {
            Text("Sum")
            Spacer()
            Text(formattedBytes(sumBytes))
          }
          HStack {
            Text("Total Physical")
            Spacer()
            Text(formattedBytes(totalDeviceMemoryBytes))
          }

          HStack {
            Text("Available to App")
            Spacer()
            Text(formattedBytes(appAvailableBytes))
          }

          HStack {
            Text("Unavailable Remainder")
            Spacer()
            Text(formattedBytes(appUnavailableBytes))
          }
        }

        Section(header: Text("Processor Information")) {
          HStack {
            Text("CPU Usage")
            Spacer()
            Text("\(cpuUsage, specifier: "%.2f")%")
          }

          HStack {
            Text("- User")
            Spacer()
            Text("\(userCPUUsage, specifier: "%.2f")%")
          }

          HStack {
            Text("- System")
            Spacer()
            Text("\(systemCPUUsage, specifier: "%.2f")%")
          }
          HStack {
            Text("- Idle")
            Spacer()
            Text("\(idleCPUUsage, specifier: "%.2f")%")
          }
          HStack {
            Text("- Nice")
            Spacer()
            Text("\(niceCPUUsage, specifier: "%.2f")%")
          }
          HStack {
            Text("Active Processors")
            Spacer()
            Text("\(activeProcessors)")
          }
        }

        Section(header: Text("Thermal State")) {
          HStack {
            Text("Thermal State")
            Spacer()
            Text(thermalState)
          }
        }

        Section(header: Text("Disk Space Information")) {
          HStack {
            Text("Total Disk")
            Spacer()
            Text(formattedBytes(totalDiskSpace))
          }

          HStack {
            Text("Used Disk")
            Spacer()
            Text(formattedBytes(usedDiskSpace))
          }

          HStack {
            Text("Free Disk")
            Spacer()
            Text(formattedBytes(freeDiskSpace))
          }
        }

        Section(header: Text("Device Information")) {
          HStack {
            Text("Uptime")
            Spacer()
            Text(totalUptime)
              .scaledToFit()
              .minimumScaleFactor(0.5)
          }

          HStack {
            Text("OS")
            Spacer()
            Text(osVersion)
          }

          HStack {
            Text("Device Type")
            Spacer()
            Text(deviceType)
          }

          HStack {
            Text(uniqueString)
              .scaledToFit()
              .minimumScaleFactor(0.5)
          }
        }
      }
      .navigationTitle("System Statistics")
      .onAppear {
        updateDeviceStats()
        updateMemoryStats()
        updateCPUUsage()
        updateDiskUsage()
        updateThermalState()
      }
      .onReceive(timer) { _ in
        updateDeviceStats()
        updateMemoryStats()
        updateCPUUsage()
        updateDiskUsage()
        updateThermalState()
      }
    }
  }

  private func formattedBytes(_ bytes: Double) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB]
    formatter.countStyle = .memory
    formatter.includesUnit = true
    formatter.isAdaptive = true
    formatter.zeroPadsFractionDigits = true

    return formatter.string(fromByteCount: Int64(bytes))
  }

  private func color(fromCategory: String) -> Color {
    var colorForCategory = Color.black

    switch fromCategory {
    case "Free":
      colorForCategory = .green
    case "Compressed":
      colorForCategory = .red
    case "Inactive":
      colorForCategory = .purple
    case "Wired":
      colorForCategory = .blue
    case "Active":
      colorForCategory = .teal

    default:
      colorForCategory = .green
    }

//        return Gradient(colors: [colorForCategory, colorForCategory.opacity(0.2)])
    return colorForCategory
  }

  func updateDeviceStats() {
    // Use the host_basic_info data
    let hostInfo = getHostBasicInfo()
    totalDeviceMemoryBytes = Double(hostInfo.max_mem)

    // Fetch memory pressure info
    let memoryInfo = getMemoryInfo()
    freeBytes = Double(memoryInfo.free)
    activeBytes = Double(memoryInfo.active)
    inactiveBytes = Double(memoryInfo.inactive)
    wiredBytes = Double(memoryInfo.wired)
    compressedBytes = Double(memoryInfo.compressed)
    sumBytes = Double(memoryInfo.totalUsed)

    memoryStats.append(MemoryStat(category: "Free", value: freeBytes, timestamp: Date()))
    memoryStats.append(MemoryStat(category: "Active", value: activeBytes, timestamp: Date()))
    memoryStats.append(MemoryStat(category: "Inactive", value: inactiveBytes, timestamp: Date()))
    memoryStats.append(MemoryStat(category: "Wired", value: wiredBytes, timestamp: Date()))
    memoryStats.append(MemoryStat(category: "Compressed", value: compressedBytes, timestamp: Date()))

    UIDevice.current.isBatteryMonitoringEnabled = true
    batteryLevel = UIDevice.current.batteryLevel
    batteryState = UIDevice.current.batteryState

    let uptime = ProcessInfo.processInfo.systemUptime
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.day, .hour, .minute, .second]

    let uptimeDate = Date(timeIntervalSinceNow: -uptime)
    let formattedUptime = formatter.string(from: uptimeDate, to: Date()) ?? "Calculating..."
    totalUptime = "\(formattedUptime)"

    let model = UIDevice.current.localizedModel
    phoneModel = model

    let version = ProcessInfo.processInfo.operatingSystemVersionString
    osVersion = "\(version)"

    let uuid = UIDevice.current.identifierForVendor?.uuidString ?? "Unavailable"
    uniqueString = "\(uuid)"

    switch UIDevice.current.userInterfaceIdiom {
    case .unspecified:
      deviceType = "Unspecified"
    case .phone:
      deviceType = "iPhone" // iPhone and iPod touch style UI
    case .pad:
      deviceType = "iPad" // iPad style UI
    case .tv:
      deviceType = "Apple TV" // Apple TV style UI
    case .carPlay:
      deviceType = "CarPlay" // CarPlay style UI
    case .mac:
      deviceType = "Mac" // Optimized for Mac UI (e.g., Mac Catalyst)
    default:
      deviceType = "Vision"
    }
  }

  func batteryStateDescription(_ state: UIDevice.BatteryState) -> String {
    switch state {
    case .unplugged:
      return "Unplugged"
    case .charging:
      return "Charging"
    case .full:
      return "Full"
    case .unknown:
      return "Unknown"
    @unknown default:
      return "Not Available"
    }
  }

  private func updateMemoryStats() {
    let totalPhysicalMemory = ProcessInfo.processInfo.physicalMemory
    physicalMemoryBytes = Double(totalPhysicalMemory)

    let availableBytes = os_proc_available_memory()
    appAvailableBytes = Double(availableBytes)

    appUnavailableBytes = physicalMemoryBytes - appAvailableBytes
  }

  private func updateCPUUsage() {
    guard let newInfo = hostCPULoadInfo() else {
      cpuUsage = 0
      userCPUUsage = 0
      systemCPUUsage = 0
      idleCPUUsage = 0
      niceCPUUsage = 0
      return
    }

    if let lastInfo = lastCPUInfo {
      let userDiff = Double(newInfo.cpu_ticks.0 - lastInfo.cpu_ticks.0)
      let systemDiff = Double(newInfo.cpu_ticks.1 - lastInfo.cpu_ticks.1)
      let idleDiff = Double(newInfo.cpu_ticks.2 - lastInfo.cpu_ticks.2)
      let niceDiff = Double(newInfo.cpu_ticks.3 - lastInfo.cpu_ticks.3)

      let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
      let nonIdleTicks = totalDiff - idleDiff

      if totalDiff > 0 {
        cpuUsage = (nonIdleTicks / totalDiff) * 100
        userCPUUsage = (userDiff / totalDiff) * 100
        systemCPUUsage = (systemDiff / totalDiff) * 100
        idleCPUUsage = (idleDiff / totalDiff) * 100
        niceCPUUsage = (niceDiff / totalDiff) * 100
      }
    }

    // Update last info for the next calculation
    lastCPUInfo = newInfo

    // Get active processor count
    activeProcessors = ProcessInfo.processInfo.activeProcessorCount
    totalProcessors = ProcessInfo.processInfo.processorCount
  }

  func hostCPULoadInfo() -> host_cpu_load_info? {
    let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
    var size = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
    var cpuLoadInfo = host_cpu_load_info()

    let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
      $0.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) {
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
      }
    }
    if result != KERN_SUCCESS {
      print("Error  - \(#file): \(#function) - kern_result_t = \(result)")
      return nil
    }
    return cpuLoadInfo
  }

  func getMemoryInfo()
    -> (free: UInt64, active: UInt64, inactive: UInt64, wired: UInt64, compressed: UInt64, totalUsed: UInt64, physicalMemory: UInt64) {
    var host_size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.stride)
    var host_info = vm_statistics64_data_t()
    let result = withUnsafeMutablePointer(to: &host_info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(host_size)) {
        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &host_size)
      }
    }

    if result == KERN_SUCCESS {
      let pageSize = vm_kernel_page_size

      // Calculate the basic memory statistics
      let free = UInt64(host_info.free_count) * UInt64(pageSize)
      let active = UInt64(host_info.active_count) * UInt64(pageSize)
      let inactive = UInt64(host_info.inactive_count) * UInt64(pageSize)
      let wired = UInt64(host_info.wire_count) * UInt64(pageSize)
      let compressed = UInt64(host_info.compressor_page_count) * UInt64(pageSize)
      let totalUsed = active + inactive + wired + compressed

      // Use host_info to get physical memory size for pressure calculation
      let hostInfo = getHostBasicInfo() // Assume this function is implemented to fetch host_basic_info
      let physicalMemory = hostInfo.max_mem

      return (free, active, inactive, wired, compressed, totalUsed, physicalMemory)
    } else {
      return (0, 0, 0, 0, 0, 0, 0)
    }
  }

  func getHostBasicInfo() -> host_basic_info {
    var size = mach_msg_type_number_t(MemoryLayout<host_basic_info>.size / MemoryLayout<integer_t>.size)
    let hostInfo = host_basic_info_t.allocate(capacity: 1)

    defer {
      hostInfo.deallocate()
    }

    var hostInfoData = host_basic_info()

    let result = withUnsafeMutablePointer(to: &hostInfoData) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
        host_info(mach_host_self(), HOST_BASIC_INFO, $0, &size)
      }
    }

    if result == KERN_SUCCESS {
      return hostInfoData
    } else {
      // Handle error - perhaps return a default struct with zeros or nil
      return host_basic_info()
    }
  }

  private func updateDiskUsage() {
    let fileManager = FileManager.default
    do {
      let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
      let freeSpace = attributes[.systemFreeSize] as? NSNumber
      let totalSpace = attributes[.systemSize] as? NSNumber

      if let freeSpace, let totalSpace {
        let freeSpaceBytes = Double(truncating: freeSpace)
        let totalSpaceBytes = Double(truncating: totalSpace)
        let usedSpaceBytes = totalSpaceBytes - freeSpaceBytes

        freeDiskSpace = freeSpaceBytes
        totalDiskSpace = totalSpaceBytes
        usedDiskSpace = usedSpaceBytes
      }
    } catch {
      freeDiskSpace = 0
      totalDiskSpace = 0
      usedDiskSpace = 0
    }
  }

  private func updateThermalState() {
    let thermalStatus = ProcessInfo.processInfo.thermalState
    switch thermalStatus {
    case .nominal:
      thermalState = "Nominal"
    case .fair:
      thermalState = "Fair"
    case .serious:
      thermalState = "Serious"
    case .critical:
      thermalState = "Critical"
    default:
      thermalState = "Unknown"
    }
  }
}

#Preview {
  StatisticsView()
}
