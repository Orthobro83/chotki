#include "Bridge.h"

#include <QJsonDocument>
#include <QJsonObject>

Bridge::Bridge(const QString &program, QObject *parent) : QObject(parent) {
    connect(&m_process, &QProcess::started, this, [this] {
        m_status = "Swift core connected";
        emit changed();
        refresh();
    });
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &Bridge::readResponses);
    connect(&m_process, &QProcess::errorOccurred, this, [this] {
        m_status = "Bridge process failed";
        m_error = m_process.errorString();
        emit changed();
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        m_error = QString::fromUtf8(m_process.readAllStandardError());
        emit changed();
    });
    m_process.start(program);
}

Bridge::~Bridge() {
    m_process.closeWriteChannel();
    if (!m_process.waitForFinished(1500)) {
        m_process.kill();
        m_process.waitForFinished(1500);
    }
}

void Bridge::refresh() { request("snapshot"); }
void Bridge::save(const QString &value) { request("save", value); }
void Bridge::probeError() { request("deliberately_unknown"); }

void Bridge::request(const QString &operation, const QString &value) {
    if (m_process.state() != QProcess::Running) return;
    QJsonObject object{{"id", m_nextId++}, {"op", operation}};
    if (operation == "save") object.insert("value", value);
    m_process.write(QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n');
}

void Bridge::readResponses() {
    m_pending += m_process.readAllStandardOutput();
    qsizetype newline;
    while ((newline = m_pending.indexOf('\n')) >= 0) {
        const QByteArray line = m_pending.left(newline);
        m_pending.remove(0, newline + 1);
        const QJsonDocument document = QJsonDocument::fromJson(line);
        if (!document.isObject()) {
            m_error = "Malformed response from Swift bridge";
            emit changed();
            continue;
        }
        const QJsonObject response = document.object();
        if (!response.value("ok").toBool()) {
            m_error = response.value("error").toString();
        } else {
            m_error.clear();
            if (response.contains("nextDay")) m_nextDay = response.value("nextDay").toString();
            if (response.contains("resource")) m_resource = response.value("resource").toString();
            if (response.contains("saved")) m_saved = response.value("saved").toString();
        }
        emit changed();
    }
}
