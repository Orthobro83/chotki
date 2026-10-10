#include "Bridge.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QProcess>
#include <QDate>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QUrl>
#include <utility>

Bridge::Bridge(QString program, bool review, QObject *parent)
    : QObject(parent), m_program(std::move(program)), m_review(review) {
    m_artworkRoot = qEnvironmentVariable("CHOTKI_ARTWORK_ROOT");
    QFile orderFile(QDir(m_artworkRoot).filePath("sayings/order.txt"));
    if (!m_artworkRoot.isEmpty() && orderFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        for (const QByteArray &line : orderFile.readAll().split('\n')) {
            const QString name = QString::fromUtf8(line).trimmed();
            if (!name.isEmpty()) m_artworkOrder.push_back(name);
        }
    }
    connect(&m_process, &QProcess::started, this, [this] {
        m_status = "Loading your record…";
        m_error.clear();
        emit changed();
        send("hello");
        refresh();
    });
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &Bridge::readResponses);
    connect(&m_process, &QProcess::finished, this, &Bridge::stopped);
    connect(&m_process, &QProcess::errorOccurred, this, [this] {
        m_error = m_process.errorString();
        m_connected = false;
        emit changed();
    });
    start();
}

Bridge::~Bridge() {
    m_closing = true;
    m_process.closeWriteChannel();
    if (m_process.state() != QProcess::NotRunning && !m_process.waitForFinished(1500)) {
        m_process.kill();
        m_process.waitForFinished(1500);
    }
}

void Bridge::start() {
    m_pending.clear();
    m_snapshotReady = false;
    m_process.start(m_program, {m_review ? "--review" : "--normal"});
}

void Bridge::stopped() {
    m_connected = false;
    m_snapshotReady = false;
    if (m_closing) return;
    if (m_restarts >= 3) {
        m_status = "The record could not be opened";
        m_error = "The Swift helper stopped repeatedly. Restart Chotki after checking its installation.";
        emit changed();
        return;
    }
    ++m_restarts;
    m_status = "Reconnecting to the record…";
    emit changed();
    QTimer::singleShot(500 * m_restarts, this, [this] { if (!m_closing) start(); });
}

namespace {

struct BridgeResponse {
    int version = 0;
    int id = 0;
    bool ok = false;
    QString error;
    bool hasMode = false;
    bool hasDisplayName = false;
    QString displayName;
    bool hasToday = false;
    QString today;
    bool hasSelectedDate = false;
    QString selectedDate;
    bool hasDayTitle = false;
    QString dayTitle;
    bool hasObservedDate = false;
    QString observedDate;
    bool hasShowOldStyleDates = false;
    bool showOldStyleDates = false;
    bool hasSayingText = false;
    QString sayingText;
    bool hasSayingAuthor = false;
    QString sayingAuthor;
    bool hasSayingSource = false;
    QString sayingSource;
    bool hasEntries = false;
    QVariantList entries;
    bool hasWeek = false;
    QVariantList week;
    bool hasPsalmOneVerses = false;
    int psalmOneVerses = 0;
};

BridgeResponse decodeResponse(const QJsonObject &object) {
    BridgeResponse response;
    response.version = object.value("v").toInt();
    response.id = object.value("id").toInt();
    response.ok = object.value("ok").toBool();
    response.error = object.value("error").toString();
    response.hasMode = object.contains("mode");
    response.hasDisplayName = object.contains("displayName");
    response.displayName = object.value("displayName").toString();
    response.hasToday = object.contains("today");
    response.today = object.value("today").toString();
    response.hasSelectedDate = object.contains("selectedDate");
    response.selectedDate = object.value("selectedDate").toString();
    response.hasDayTitle = object.contains("dayTitle");
    response.dayTitle = object.value("dayTitle").toString();
    response.hasObservedDate = object.contains("observedDate");
    response.observedDate = object.value("observedDate").toString();
    response.hasShowOldStyleDates = object.contains("showOldStyleDates");
    response.showOldStyleDates = object.value("showOldStyleDates").toBool();
    response.hasSayingText = object.contains("sayingText");
    response.sayingText = object.value("sayingText").toString();
    response.hasSayingAuthor = object.contains("sayingAuthor");
    response.sayingAuthor = object.value("sayingAuthor").toString();
    response.hasSayingSource = object.contains("sayingSource");
    response.sayingSource = object.value("sayingSource").toString();
    response.hasEntries = object.contains("entries");
    response.entries = object.value("entries").toArray().toVariantList();
    response.hasWeek = object.contains("week");
    response.week = object.value("week").toArray().toVariantList();
    response.hasPsalmOneVerses = object.contains("psalmOneVerses");
    response.psalmOneVerses = object.value("psalmOneVerses").toInt();
    return response;
}

}

void Bridge::send(const QString &operation, const QJsonObject &fields) {
    if (m_process.state() != QProcess::Running) return;
    QJsonObject request{{"v", protocolVersion}, {"id", m_nextId++}, {"op", operation}};
    for (auto it = fields.begin(); it != fields.end(); ++it) request.insert(it.key(), it.value());
    m_process.write(QJsonDocument(request).toJson(QJsonDocument::Compact) + '\n');
}

void Bridge::refresh() { send("snapshot"); }
void Bridge::setReviewName(const QString &name) { if (m_review) send("setReviewName", QJsonObject{{"name", name}}); }
void Bridge::selectDate(const QString &date) { send("selectDate", QJsonObject{{"date", date}}); }
void Bridge::toggleKept(const QString &ruleID) { send("toggleKept", QJsonObject{{"ruleID", ruleID}}); }
void Bridge::shiftWeek(int direction) {
    if (direction == -1 || direction == 1) send("shiftWeek", QJsonObject{{"direction", direction}});
}

void Bridge::readResponses() {
    m_pending += m_process.readAllStandardOutput();
    qsizetype newline;
    while ((newline = m_pending.indexOf('\n')) >= 0) {
        const QByteArray line = m_pending.left(newline);
        m_pending.remove(0, newline + 1);
        const QJsonDocument document = QJsonDocument::fromJson(line);
        if (!document.isObject()) {
            m_error = "The Swift helper sent an invalid response.";
            emit changed();
            continue;
        }
        const BridgeResponse response = decodeResponse(document.object());
        if (response.version != protocolVersion) {
            m_error = "The Linux interface and Swift helper use different protocol versions.";
            emit changed();
            continue;
        }
        // A reply for an earlier request must not wipe a newer success, and an
        // error must not blank the snapshot the newer success already showed.
        if (!response.ok) {
            if (response.id > m_newestSuccessId) {
                m_error = response.error;
                emit changed();
            }
            continue;
        }
        if (response.hasMode) {
            m_connected = true;
            m_status = "Ready";
            m_restarts = 0;
        }
        if (response.id < m_newestSuccessId) {
            emit changed();
            continue;
        }
        m_newestSuccessId = response.id;
        m_error.clear();
        if (response.hasDisplayName) m_displayName = response.displayName;
        if (response.hasToday) m_today = response.today;
        if (response.hasSelectedDate) {
            m_snapshotReady = true;
            m_selectedDate = response.selectedDate;
            const QDate date = QDate::fromString(m_selectedDate, Qt::ISODate);
            m_artworkUrl.clear();
            if (date.isValid() && !m_artworkOrder.isEmpty()) {
                const QString name = m_artworkOrder.at(date.dayOfYear() % m_artworkOrder.size());
                const QString path = QDir(m_artworkRoot).filePath(name);
                if (QFileInfo::exists(path)) m_artworkUrl = QUrl::fromLocalFile(path).toString();
            }
        }
        if (response.hasDayTitle) m_dayTitle = response.dayTitle;
        if (response.hasObservedDate) m_observedDate = response.observedDate;
        if (response.hasShowOldStyleDates) m_showOldStyleDates = response.showOldStyleDates;
        if (response.hasSayingText) m_sayingText = response.sayingText;
        if (response.hasSayingAuthor) m_sayingAuthor = response.sayingAuthor;
        if (response.hasSayingSource) m_sayingSource = response.sayingSource;
        if (response.hasEntries) m_entries = response.entries;
        if (response.hasWeek) m_week = response.week;
        if (response.hasPsalmOneVerses) m_psalmOneVerses = response.psalmOneVerses;
        emit changed();
    }
}
