#include "iconprovider.h"

#include <QCoreApplication>
#include <QColor>
#include <QDir>
#include <QFileInfo>
#include <QPainter>
#include <QStandardPaths>
#include <QStringList>
#include <QSvgRenderer>

namespace {
QStringList overrideFileNamesForId(const QString &id) {
    if (id == QStringLiteral("folder")) return {QStringLiteral("folder.fill.svg"), QStringLiteral("folder.svg"), QStringLiteral("folder-open.svg")};
    if (id == QStringLiteral("link")) return {QStringLiteral("link.svg")};
    if (id == QStringLiteral("pause")) return {QStringLiteral("pause.fill.svg"), QStringLiteral("pause.svg")};
    if (id == QStringLiteral("play")) return {QStringLiteral("play.fill.svg"), QStringLiteral("play.svg")};
    if (id == QStringLiteral("trash")) return {QStringLiteral("trash.fill.svg"), QStringLiteral("trash.svg")};
    if (id == QStringLiteral("harddrive")) return {QStringLiteral("internaldrive.fill.svg"), QStringLiteral("internaldrive.svg"), QStringLiteral("externaldrive.fill.svg"), QStringLiteral("harddrive.svg"), QStringLiteral("hard-drive.svg")};
    if (id == QStringLiteral("activity")) return {QStringLiteral("waveform.path.ecg.svg"), QStringLiteral("waveform.path.ecg.rectangle.fill.svg"), QStringLiteral("activity.svg")};
    if (id == QStringLiteral("arrowdown")) return {QStringLiteral("arrow.down.to.line.svg"), QStringLiteral("arrow.down.to.line.circle.fill.svg"), QStringLiteral("arrow.down.svg"), QStringLiteral("arrowdown.svg"), QStringLiteral("arrow-down.svg")};
    if (id == QStringLiteral("download")) return {QStringLiteral("square.and.arrow.down.fill.svg"), QStringLiteral("arrow.down.to.line.svg"), QStringLiteral("download.svg")};
    if (id == QStringLiteral("check")) return {QStringLiteral("checkmark.svg"), QStringLiteral("checkmark.circle.fill.svg"), QStringLiteral("check.svg")};
    if (id == QStringLiteral("clock")) return {QStringLiteral("clock.fill.svg"), QStringLiteral("clock.svg")};
    if (id == QStringLiteral("archive")) return {QStringLiteral("archivebox.fill.svg"), QStringLiteral("archivebox.svg"), QStringLiteral("archive.svg")};
    if (id == QStringLiteral("video")) return {QStringLiteral("video.fill.svg"), QStringLiteral("video.svg"), QStringLiteral("film.fill.svg")};
    if (id == QStringLiteral("audio")) return {QStringLiteral("music.note.svg"), QStringLiteral("music.note.list.svg"), QStringLiteral("audio.svg")};
    if (id == QStringLiteral("document")) return {QStringLiteral("doc.text.fill.svg"), QStringLiteral("doc.text.svg"), QStringLiteral("document.svg")};
    if (id == QStringLiteral("image")) return {QStringLiteral("photo.fill.svg"), QStringLiteral("photo.svg"), QStringLiteral("image.svg")};
    if (id == QStringLiteral("file")) return {QStringLiteral("doc.fill.svg"), QStringLiteral("doc.svg"), QStringLiteral("file.svg")};
    if (id == QStringLiteral("search")) return {QStringLiteral("magnifyingglass.svg"), QStringLiteral("search.svg")};
    if (id == QStringLiteral("plus")) return {QStringLiteral("plus.svg"), QStringLiteral("plus.circle.fill.svg")};
    if (id == QStringLiteral("close")) return {QStringLiteral("xmark.svg"), QStringLiteral("xmark.circle.fill.svg"), QStringLiteral("close.svg")};
    return {id + QStringLiteral(".svg")};
}

QStringList overrideDirectories() {
    QStringList dirs;

    const QString envDir = qEnvironmentVariable("DYX_ICON_DIR");
    if (!envDir.isEmpty()) {
        dirs.append(QDir::cleanPath(envDir));
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    if (!appDir.isEmpty()) {
        dirs.append(QDir(appDir).filePath(QStringLiteral("icons")));
    }

    dirs.append(QDir::current().filePath(QStringLiteral("icons")));
    dirs.append(QDir::current().filePath(QStringLiteral("qt/resources/icons-custom")));

    const QString configDir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (!configDir.isEmpty()) {
        dirs.append(QDir(configDir).filePath(QStringLiteral("icons")));
    }

    dirs.removeDuplicates();
    return dirs;
}

QString overrideFileForId(const QString &id) {
    const QStringList fileNames = overrideFileNamesForId(id);
    const QStringList dirs = overrideDirectories();

    for (const QString &dirPath : dirs) {
        QDir dir(dirPath);
        if (!dir.exists()) {
            continue;
        }

        for (const QString &fileName : fileNames) {
            const QString candidate = dir.filePath(fileName);
            if (QFileInfo::exists(candidate)) {
                return QFileInfo(candidate).canonicalFilePath();
            }
        }
    }

    return {};
}

QString resourceForId(const QString &id) {
    if (id == QStringLiteral("folder")) return QStringLiteral(":/icons/resources/icons/folder-open.svg");
    if (id == QStringLiteral("link")) return QStringLiteral(":/icons/resources/icons/link.svg");
    if (id == QStringLiteral("pause")) return QStringLiteral(":/icons/resources/icons/pause.svg");
    if (id == QStringLiteral("play")) return QStringLiteral(":/icons/resources/icons/play.svg");
    if (id == QStringLiteral("trash")) return QStringLiteral(":/icons/resources/icons/trash.svg");
    if (id == QStringLiteral("harddrive")) return QStringLiteral(":/icons/resources/icons/harddrive.svg");
    if (id == QStringLiteral("activity")) return QStringLiteral(":/icons/resources/icons/activity.svg");
    if (id == QStringLiteral("arrowdown")) return QStringLiteral(":/icons/resources/icons/arrowdown.svg");
    if (id == QStringLiteral("download")) return QStringLiteral(":/icons/resources/icons/download.svg");
    if (id == QStringLiteral("check")) return QStringLiteral(":/icons/resources/icons/check.svg");
    if (id == QStringLiteral("clock")) return QStringLiteral(":/icons/resources/icons/clock.svg");
    if (id == QStringLiteral("archive")) return QStringLiteral(":/icons/resources/icons/archive.svg");
    if (id == QStringLiteral("video")) return QStringLiteral(":/icons/resources/icons/video.svg");
    if (id == QStringLiteral("audio")) return QStringLiteral(":/icons/resources/icons/audio.svg");
    if (id == QStringLiteral("document")) return QStringLiteral(":/icons/resources/icons/document.svg");
    if (id == QStringLiteral("image")) return QStringLiteral(":/icons/resources/icons/image.svg");
    if (id == QStringLiteral("file")) return QStringLiteral(":/icons/resources/icons/file.svg");
    if (id == QStringLiteral("search")) return QStringLiteral(":/icons/resources/icons/search.svg");
    if (id == QStringLiteral("plus")) return QStringLiteral(":/icons/resources/icons/plus.svg");
    if (id == QStringLiteral("close")) return QStringLiteral(":/icons/resources/icons/close.svg");
    return {};
}

QString iconSourceForId(const QString &id) {
    const QString overrideFile = overrideFileForId(id);
    return overrideFile.isEmpty() ? resourceForId(id) : overrideFile;
}

QString iconNameFromRequest(const QString &id) {
    const int separatorIndex = id.indexOf('/');
    return separatorIndex >= 0 ? id.left(separatorIndex) : id;
}

QColor colorFromRequest(const QString &id) {
    const int separatorIndex = id.indexOf('/');
    if (separatorIndex < 0 || separatorIndex + 1 >= id.size()) {
        return QColor(QStringLiteral("#fbfbfb"));
    }

    QString colorValue = id.mid(separatorIndex + 1);
    if (!colorValue.startsWith('#')) {
        colorValue.prepend('#');
    }
    const QColor parsed(colorValue);
    return parsed.isValid() ? parsed : QColor(QStringLiteral("#fbfbfb"));
}
}

DyxIconProvider::DyxIconProvider()
    : QQuickImageProvider(QQuickImageProvider::Image) {}

QImage DyxIconProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    const QString resource = iconSourceForId(iconNameFromRequest(id));
    const QColor tintColor = colorFromRequest(id);
    const QSize finalSize = requestedSize.isValid() ? requestedSize : QSize(32, 32);

    QImage image(finalSize, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);

    if (resource.isEmpty()) {
        if (size) {
            *size = finalSize;
        }
        return image;
    }

    QSvgRenderer renderer(resource);
    if (!renderer.isValid()) {
        if (size) {
            *size = finalSize;
        }
        return image;
    }

    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    renderer.render(&painter);
    painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
    painter.fillRect(image.rect(), tintColor);
    painter.end();

    if (size) {
        *size = finalSize;
    }
    return image;
}
