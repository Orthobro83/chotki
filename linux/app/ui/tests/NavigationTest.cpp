#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtTest>

class SampleBridge final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected MEMBER connected CONSTANT)
    Q_PROPERTY(bool review MEMBER review CONSTANT)
    Q_PROPERTY(QString status MEMBER status CONSTANT)
    Q_PROPERTY(QString error MEMBER error CONSTANT)
    Q_PROPERTY(QString displayName MEMBER displayName CONSTANT)
    Q_PROPERTY(QString today MEMBER today CONSTANT)

public:
    bool connected = true;
    bool review = true;
    QString status = "Ready";
    QString error;
    QString displayName = "Anna";
    QString today = "2026-10-07";
};

class NavigationTest final : public QObject {
    Q_OBJECT

    static QQuickItem *findItem(QQuickItem *root, const QString &name) {
        if (root->objectName() == name) return root;
        for (QQuickItem *child : root->childItems()) {
            if (auto *found = findItem(child, name)) return found;
        }
        return nullptr;
    }

private slots:
    void clickSidebarItem() {
        SampleBridge bridge;
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("bridge", &bridge);
        engine.load(QUrl::fromLocalFile(CHOTKI_QML_SOURCE));
        QCOMPARE(engine.rootObjects().size(), 1);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QTRY_VERIFY(window->isVisible());

        QQuickItem *item = nullptr;
        QTRY_VERIFY_WITH_TIMEOUT((item = findItem(window->contentItem(), "nav-Prayers")), 3000);
        QVERIFY(item);
        const QPointF center = item->mapToScene(QPointF(item->width() / 2, item->height() / 2));
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, center.toPoint());
        QTRY_COMPARE(window->property("section").toString(), QString("Prayers"));
    }
};

QTEST_MAIN(NavigationTest)
#include "NavigationTest.moc"
