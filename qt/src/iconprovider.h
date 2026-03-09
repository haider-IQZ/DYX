#pragma once

#include <QQuickImageProvider>

class DyxIconProvider final : public QQuickImageProvider {
public:
    DyxIconProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};
