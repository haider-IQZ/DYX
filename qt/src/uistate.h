#pragma once

#include <QObject>

class UiState final : public QObject {
    Q_OBJECT
    Q_PROPERTY(qreal scale READ scale WRITE setScale NOTIFY scaleChanged)

public:
    explicit UiState(QObject *parent = nullptr);

    qreal scale() const;
    void setScale(qreal value);

    Q_INVOKABLE void zoomIn();
    Q_INVOKABLE void zoomOut();
    Q_INVOKABLE void resetScale();

signals:
    void scaleChanged();

private:
    static constexpr qreal kDefaultScale = 1.0;
    static constexpr qreal kMinScale = 0.8;
    static constexpr qreal kMaxScale = 1.5;
    static constexpr qreal kZoomStep = 0.1;

    static qreal clampScale(qreal value);

    qreal m_scale = kDefaultScale;
};
