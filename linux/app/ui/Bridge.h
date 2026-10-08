#pragma once

#include <QObject>
#include <QProcess>
#include <QString>
#include <QTimer>
#include <QVariantList>

class Bridge final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(bool review READ review NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString displayName READ displayName NOTIFY changed)
    Q_PROPERTY(QString today READ today NOTIFY changed)
    Q_PROPERTY(QString selectedDate READ selectedDate NOTIFY changed)
    Q_PROPERTY(QString dayTitle READ dayTitle NOTIFY changed)
    Q_PROPERTY(QString sayingText READ sayingText NOTIFY changed)
    Q_PROPERTY(QString sayingAuthor READ sayingAuthor NOTIFY changed)
    Q_PROPERTY(QString sayingSource READ sayingSource NOTIFY changed)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY changed)
    Q_PROPERTY(QVariantList week READ week NOTIFY changed)
    Q_PROPERTY(int psalmOneVerses READ psalmOneVerses NOTIFY changed)

public:
    Bridge(QString program, bool review, QObject *parent = nullptr);
    ~Bridge() override;

    bool connected() const { return m_connected; }
    bool review() const { return m_review; }
    QString status() const { return m_status; }
    QString error() const { return m_error; }
    QString displayName() const { return m_displayName; }
    QString today() const { return m_today; }
    QString selectedDate() const { return m_selectedDate; }
    QString dayTitle() const { return m_dayTitle; }
    QString sayingText() const { return m_sayingText; }
    QString sayingAuthor() const { return m_sayingAuthor; }
    QString sayingSource() const { return m_sayingSource; }
    QVariantList entries() const { return m_entries; }
    QVariantList week() const { return m_week; }
    int psalmOneVerses() const { return m_psalmOneVerses; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setReviewName(const QString &name);
    Q_INVOKABLE void selectDate(const QString &date);
    Q_INVOKABLE void toggleKept(const QString &ruleID);
    Q_INVOKABLE void shiftWeek(int direction);

signals:
    void changed();

private:
    void start();
    void send(const QString &operation, const QString &name = {});
    void readResponses();
    void stopped();

    static constexpr int protocolVersion = 1;
    QProcess m_process;
    QString m_program;
    QByteArray m_pending;
    int m_nextId = 1;
    int m_restarts = 0;
    bool m_review;
    bool m_closing = false;
    bool m_connected = false;
    QString m_status = "Connecting to the record…";
    QString m_error;
    QString m_displayName;
    QString m_today;
    QString m_selectedDate;
    QString m_dayTitle;
    QString m_sayingText;
    QString m_sayingAuthor;
    QString m_sayingSource;
    QVariantList m_entries;
    QVariantList m_week;
    int m_psalmOneVerses = 0;
};
