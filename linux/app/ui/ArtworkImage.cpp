#include "ArtworkImage.h"

#include <QImageReader>
#include <QLinearGradient>
#include <QPainter>
#include <QPainterPath>

#include <algorithm>

ArtworkImage::ArtworkImage(QQuickItem *parent) : QQuickPaintedItem(parent) {
    setAntialiasing(true);
}

void ArtworkImage::setSource(const QUrl &source) {
    if (m_source == source) return;
    m_source = source;
    m_image = {};
    if (source.isLocalFile()) {
        QImageReader reader(source.toLocalFile());
        reader.setAutoTransform(true);
        m_image = reader.read();
    }
    emit sourceChanged();
    update();
}

void ArtworkImage::paint(QPainter *painter) {
    if (m_image.isNull() || width() <= 0 || height() <= 0) return;
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setRenderHint(QPainter::SmoothPixmapTransform);
    QPainterPath rounded;
    rounded.addRoundedRect(QRectF(0, 0, width(), height()), 20, 20);
    painter->setClipPath(rounded);

    const qreal scale = std::max(width() / m_image.width(), height() / m_image.height());
    const QSizeF size(m_image.width() * scale, m_image.height() * scale);
    const QRectF target((width() - size.width()) / 2, (height() - size.height()) / 2,
                        size.width(), size.height());
    painter->drawImage(target, m_image);

    QLinearGradient shade(0, 0, 0, height());
    shade.setColorAt(0, QColor(0, 0, 0, 0));
    shade.setColorAt(0.58, QColor(0, 0, 0, 66));
    shade.setColorAt(1, QColor(0, 0, 0, 224));
    painter->fillRect(QRectF(0, 0, width(), height()), shade);
}
