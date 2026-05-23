import Foundation

DistributedNotificationCenter.default().addObserver(
    forName: .init("fr.mathieu-dubart.Cassette.nowPlaying"),
    object: nil,
    queue: .main
) { notif in
    print("Reçu :", notif.userInfo ?? [:])
}

print("En attente...")
RunLoop.main.run()
