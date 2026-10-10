#include "Bridge.h"

#include <QTemporaryDir>
#include <QtTest>

#include <signal.h>
#include <unistd.h>

class BridgeRestartTest final : public QObject {
    Q_OBJECT

private slots:
    void helperReconnectsAfterRepeatedDeath() {
        const QString program = qEnvironmentVariable("CHOTKI_LINUX_BRIDGE");
        if (program.isEmpty()) QSKIP("CHOTKI_LINUX_BRIDGE is not set");

        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("CHOTKI_LINUX_REVIEW_DIR", directory.path().toUtf8());

        Bridge bridge(program, true);
        QTRY_VERIFY_WITH_TIMEOUT(bridge.snapshotReady(), 8000);
        QCOMPARE(bridge.status(), QString("Ready"));

        for (int attempt = 0; attempt < 4; ++attempt) {
            const qint64 previous = bridge.helperProcessId();
            QVERIFY2(previous > 0, "The helper was not running");
            QVERIFY(::kill(static_cast<pid_t>(previous), SIGKILL) == 0);
            QTRY_VERIFY_WITH_TIMEOUT(!bridge.connected() || bridge.helperProcessId() != previous, 4000);
            QTRY_VERIFY_WITH_TIMEOUT(bridge.snapshotReady() && bridge.helperProcessId() > 0
                                     && bridge.helperProcessId() != previous, 8000);
            QCOMPARE(bridge.status(), QString("Ready"));
        }
    }
};

QTEST_GUILESS_MAIN(BridgeRestartTest)
#include "BridgeRestartTest.moc"
