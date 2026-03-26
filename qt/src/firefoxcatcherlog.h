#pragma once

#include <QJsonObject>
#include <QString>

namespace FirefoxCatcherLog {

QString logDirPath();
void append(const QString &fileName, const QString &component, const QString &event, const QJsonObject &data = QJsonObject());

}
