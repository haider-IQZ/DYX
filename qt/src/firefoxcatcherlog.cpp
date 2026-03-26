#include "firefoxcatcherlog.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>

namespace {
constexpr qint64 kMaxLogBytes = 1024 * 1024;

QString resolveBaseDataDir() {
    const QString xdgDataHome = qEnvironmentVariable("XDG_DATA_HOME");
    if (!xdgDataHome.isEmpty()) {
        return QDir(xdgDataHome).filePath(QStringLiteral("DYX"));
    }
    return QDir::home().filePath(QStringLiteral(".local/share/DYX"));
}

void rotateIfNeeded(const QString &path) {
    QFileInfo info(path);
    if (!info.exists() || info.size() < kMaxLogBytes) {
        return;
    }

    const QString rotatedPath = path + QStringLiteral(".1");
    QFile::remove(rotatedPath);
    QFile::rename(path, rotatedPath);
}
}

namespace FirefoxCatcherLog {

QString logDirPath() {
    const QString dirPath = QDir(resolveBaseDataDir()).filePath(QStringLiteral("logs/firefox-catcher"));
    QDir().mkpath(dirPath);
    return dirPath;
}

void append(const QString &fileName, const QString &component, const QString &event, const QJsonObject &data) {
    const QString path = QDir(logDirPath()).filePath(fileName);
    rotateIfNeeded(path);

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        return;
    }

    QJsonObject entry{
        {QStringLiteral("ts"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
        {QStringLiteral("component"), component},
        {QStringLiteral("event"), event},
        {QStringLiteral("data"), data},
    };
    file.write(QJsonDocument(entry).toJson(QJsonDocument::Compact));
    file.write("\n");
}

}
