#include "Bridge.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <utility>

Bridge::Bridge(QString program, bool review, QObject *parent)
    : QObject(parent), m_program(std::move(program)), m_review(review) {
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
    m_process.start(m_program, {m_review ? "--review" : "--normal"});
}

void Bridge::stopped() {
    m_connected = false;
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

void Bridge::send(const QString &operation, const QString &name) {
    if (m_process.state() != QProcess::Running) return;
    QJsonObject request{{"v", protocolVersion}, {"id", m_nextId++}, {"op", operation}};
    if (operation == "setReviewName") request.insert("name", name);
    m_process.write(QJsonDocument(request).toJson(QJsonDocument::Compact) + '\n');
}

void Bridge::refresh() { send("snapshot"); }
void Bridge::setReviewName(const QString &name) { if (m_review) send("setReviewName", name); }

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
        const QJsonObject response = document.object();
        if (response.value("v").toInt() != protocolVersion) {
            m_error = "The Linux interface and Swift helper use different protocol versions.";
            emit changed();
            continue;
        }
        if (!response.value("ok").toBool()) {
            m_error = response.value("error").toString();
            emit changed();
            continue;
        }
        if (response.contains("mode")) {
            m_connected = true;
            m_status = "Ready";
        }
        if (response.contains("displayName")) m_displayName = response.value("displayName").toString();
        if (response.contains("today")) m_today = response.value("today").toString();
        if (response.contains("psalmOneVerses")) m_psalmOneVerses = response.value("psalmOneVerses").toInt();
        m_error.clear();
        emit changed();
    }
}
