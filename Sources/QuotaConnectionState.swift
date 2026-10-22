import Foundation

enum QuotaConnectionState: Equatable {
    case locating
    case ready
    case codexNotInstalled
    case authenticationRequired
    case disconnected(String)
}
