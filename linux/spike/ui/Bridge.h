#pragma once

#include <QObject>
#include <QProcess>

class Bridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString nextDay READ nextDay NOTIFY changed)
    Q_PROPERTY(QString resource READ resource NOTIFY changed)
    Q_PROPERTY(QString saved READ saved NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    explicit Bridge(const QString &program, QObject *parent = nullptr);
    ~Bridge() override;
    QString status() const { return m_status; }
    QString nextDay() const { return m_nextDay; }
    QString resource() const { return m_resource; }
    QString saved() const { return m_saved; }
    QString error() const { return m_error; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void save(const QString &value);
    Q_INVOKABLE void probeError();

signals:
    void changed();

private:
    void request(const QString &operation, const QString &value = {});
    void readResponses();

    QProcess m_process;
    QByteArray m_pending;
    int m_nextId = 1;
    QString m_status = "Starting Swift core…";
    QString m_nextDay;
    QString m_resource;
    QString m_saved;
    QString m_error;
};
