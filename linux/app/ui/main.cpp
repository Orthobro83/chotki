#include "Bridge.h"

#include <QGuiApplication>
#include <QDir>
#include <QLockFile>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QStandardPaths>

#include <unistd.h>

int main(int argc, char *argv[]) {
    QGuiApplication application(argc, argv);
    application.setApplicationName("Chotki");
    application.setDesktopFileName("org.chotki.Chotki");

    const QStringList arguments = application.arguments();
    if (arguments.size() != 3 || (arguments.at(1) != "--review" && arguments.at(1) != "--normal")) {
        qCritical("Usage: chotki-linux --review|--normal /path/to/ChotkiLinuxBridge");
        return 2;
    }
    const bool review = arguments.at(1) == "--review";
    const QString serverName = QString("org.chotki.linux.%1.%2")
        .arg(getuid()).arg(review ? "review" : "normal");

    QLocalSocket existing;
    existing.connectToServer(serverName);
    if (existing.waitForConnected(250)) {
        existing.write("activate\n");
        existing.waitForBytesWritten(250);
        return 0;
    }

    // Only the process holding this lock may remove a stale socket. A second
    // launch must never unlink the first launch's live socket.
    const QString lockPath = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation)
        + QDir::separator() + serverName + ".lock";
    QLockFile lock(lockPath);
    if (!lock.tryLock(0)) {
        existing.connectToServer(serverName);
        if (existing.waitForConnected(1000)) {
            existing.write("activate\n");
            existing.waitForBytesWritten(250);
            return 0;
        }
        qCritical("Another Chotki instance is starting but cannot be reached");
        return 3;
    }
    QLocalServer::removeServer(serverName);
    QLocalServer server;
    if (!server.listen(serverName)) {
        qCritical("Cannot establish Chotki's single-instance socket");
        return 3;
    }

    Bridge bridge(arguments.at(2), review);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("bridge", &bridge);
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/ChotkiLinux/Main.qml")));
    if (engine.rootObjects().isEmpty()) return 4;
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!window) return 5;
    QObject::connect(&server, &QLocalServer::newConnection, window, [&server, window] {
        while (QLocalSocket *socket = server.nextPendingConnection()) {
            QObject::connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
            socket->disconnectFromServer();
            window->show();
            window->raise();
            window->requestActivate();
        }
    });
    return application.exec();
}
