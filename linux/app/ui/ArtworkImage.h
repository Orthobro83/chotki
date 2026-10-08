#pragma once

#include <QImage>
#include <QQuickPaintedItem>
#include <QUrl>

class ArtworkImage : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)

public:
    explicit ArtworkImage(QQuickItem *parent = nullptr);
    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);
    void paint(QPainter *painter) override;

signals:
    void sourceChanged();

private:
    QUrl m_source;
    QImage m_image;
};
