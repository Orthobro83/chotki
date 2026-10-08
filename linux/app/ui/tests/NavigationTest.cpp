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
    Q_PROPERTY(QString selectedDate MEMBER selectedDate CONSTANT)
    Q_PROPERTY(QString dayTitle MEMBER dayTitle CONSTANT)
    Q_PROPERTY(QString observedDate MEMBER observedDate CONSTANT)
    Q_PROPERTY(bool showOldStyleDates MEMBER showOldStyleDates CONSTANT)
    Q_PROPERTY(QString sayingText MEMBER sayingText CONSTANT)
    Q_PROPERTY(QString sayingAuthor MEMBER sayingAuthor CONSTANT)
    Q_PROPERTY(QString sayingSource MEMBER sayingSource CONSTANT)
    Q_PROPERTY(QString artworkUrl MEMBER artworkUrl CONSTANT)
    Q_PROPERTY(QVariantList entries MEMBER entries CONSTANT)
    Q_PROPERTY(QVariantList week MEMBER week CONSTANT)

public:
    SampleBridge() {
        entries.push_back(QVariantMap{{"id", "sample-rule"}, {"title", "Morning prayers"},
            {"category", "Prayer"}, {"summary", "A morning prayer"},
            {"time", "06:30"}, {"kept", false}, {"dispensed", false}});
        week.push_back(QVariantMap{{"date", "2026-10-07"}, {"day", 7},
            {"weekday", 4}, {"selected", true}});
    }
    bool connected = true;
    bool review = true;
    QString status = "Ready";
    QString error;
    QString displayName = "Anna";
    QString today = "2026-10-07";
    QString selectedDate = "2026-10-07";
    QString dayTitle;
    QString observedDate;
    bool showOldStyleDates = false;
    QString sayingText = "A saying";
    QString sayingAuthor = "A father";
    QString sayingSource = "A source";
    QString artworkUrl;
    QVariantList entries;
    QVariantList week;
    QString selectedDay;
    QString toggledRule;
    Q_INVOKABLE void selectDate(const QString &date) { selectedDay = date; }
    Q_INVOKABLE void toggleKept(const QString &id) { toggledRule = id; }
    Q_INVOKABLE void shiftWeek(int) {}
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
        QTest::keyClick(window, Qt::Key_1, Qt::ControlModifier);
        QTRY_COMPARE(window->property("section").toString(), QString("Home"));
    }

    void clickHomeActions() {
        SampleBridge bridge;
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("bridge", &bridge);
        engine.load(QUrl::fromLocalFile(CHOTKI_QML_SOURCE));
        QCOMPARE(engine.rootObjects().size(), 1);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);

        QQuickItem *completion = nullptr;
        QTRY_VERIFY_WITH_TIMEOUT((completion = findItem(window->contentItem(), "completion-sample-rule")), 3000);
        QTRY_VERIFY_WITH_TIMEOUT(completion->mapToScene(QPointF(0, 0)).y() > 180, 3000);
        const QPointF completionCenter = completion->mapToScene(
            QPointF(completion->width() / 2, completion->height() / 2));
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, completionCenter.toPoint());
        QTRY_COMPARE(bridge.toggledRule, QString("sample-rule"));

        QQuickItem *day = nullptr;
        QTRY_VERIFY_WITH_TIMEOUT((day = findItem(window->contentItem(), "day-2026-10-07")), 3000);
        const QPointF dayCenter = day->mapToScene(QPointF(day->width() / 2, day->height() / 2));
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, dayCenter.toPoint());
        QTRY_COMPARE(bridge.selectedDay, QString("2026-10-07"));
    }
};

QTEST_MAIN(NavigationTest)
#include "NavigationTest.moc"
