import DeviceActivity

extension DeviceActivityName {
    static let session = DeviceActivityName("com.screentimepool.session")
    static let downtimePeriod = DeviceActivityName("com.screentimepool.downtime")
    static let test = DeviceActivityName("com.screentimepool.test")
}

extension DeviceActivityEvent.Name {
    static let sessionThreshold = DeviceActivityEvent.Name("com.screentimepool.session.threshold")
    static let testThreshold = DeviceActivityEvent.Name("com.screentimepool.test.threshold")
}
