#include "uistate.h"

#include <QtMath>

UiState::UiState(QObject *parent)
    : QObject(parent) {}

qreal UiState::scale() const {
    return m_scale;
}

void UiState::setScale(qreal value) {
    const qreal clamped = clampScale(value);
    if (qFuzzyCompare(m_scale, clamped)) {
        return;
    }
    m_scale = clamped;
    emit scaleChanged();
}

void UiState::zoomIn() {
    setScale(m_scale + kZoomStep);
}

void UiState::zoomOut() {
    setScale(m_scale - kZoomStep);
}

void UiState::resetScale() {
    setScale(kDefaultScale);
}

qreal UiState::clampScale(qreal value) {
    const qreal bounded = qBound(kMinScale, value, kMaxScale);
    return qRound(bounded * 100.0) / 100.0;
}
