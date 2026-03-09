#include "settingsmodel.h"

SettingsModel::SettingsModel(QObject *parent)
    : QObject(parent) {}

QString SettingsModel::defaultDownloadDir() const { return m_defaultDownloadDir; }
void SettingsModel::setDefaultDownloadDir(const QString &value) {
    if (m_defaultDownloadDir == value) return;
    m_defaultDownloadDir = value;
    emit changed();
}

int SettingsModel::defaultConnections() const { return m_defaultConnections; }
void SettingsModel::setDefaultConnections(int value) {
    if (m_defaultConnections == value) return;
    m_defaultConnections = value;
    emit changed();
}

int SettingsModel::defaultTimeoutSeconds() const { return m_defaultTimeoutSeconds; }
void SettingsModel::setDefaultTimeoutSeconds(int value) {
    if (m_defaultTimeoutSeconds == value) return;
    m_defaultTimeoutSeconds = value;
    emit changed();
}

int SettingsModel::maxConcurrentDownloads() const { return m_maxConcurrentDownloads; }
void SettingsModel::setMaxConcurrentDownloads(int value) {
    if (m_maxConcurrentDownloads == value) return;
    m_maxConcurrentDownloads = value;
    emit changed();
}

bool SettingsModel::defaultNoClobber() const { return m_defaultNoClobber; }
void SettingsModel::setDefaultNoClobber(bool value) {
    if (m_defaultNoClobber == value) return;
    m_defaultNoClobber = value;
    emit changed();
}

bool SettingsModel::autoRetryOnFail() const { return m_autoRetryOnFail; }
void SettingsModel::setAutoRetryOnFail(bool value) {
    if (m_autoRetryOnFail == value) return;
    m_autoRetryOnFail = value;
    emit changed();
}

QString SettingsModel::theme() const { return m_theme; }
void SettingsModel::setTheme(const QString &value) {
    if (m_theme == value) return;
    m_theme = value;
    emit changed();
}

void SettingsModel::fromJson(const QJsonObject &json) {
    m_defaultDownloadDir = json.value("defaultDownloadDir").toString(m_defaultDownloadDir);
    m_defaultConnections = json.value("defaultConnections").toInt(m_defaultConnections);
    m_defaultTimeoutSeconds = json.value("defaultTimeoutSeconds").toInt(m_defaultTimeoutSeconds);
    m_maxConcurrentDownloads = json.value("maxConcurrentDownloads").toInt(m_maxConcurrentDownloads);
    m_defaultNoClobber = json.value("defaultNoClobber").toBool(m_defaultNoClobber);
    m_autoRetryOnFail = json.value("autoRetryOnFail").toBool(m_autoRetryOnFail);
    m_theme = json.value("theme").toString(m_theme);
    emit changed();
}

QJsonObject SettingsModel::toJson() const {
    return QJsonObject{
        {"defaultDownloadDir", m_defaultDownloadDir},
        {"defaultConnections", m_defaultConnections},
        {"defaultTimeoutSeconds", m_defaultTimeoutSeconds},
        {"maxConcurrentDownloads", m_maxConcurrentDownloads},
        {"defaultNoClobber", m_defaultNoClobber},
        {"autoRetryOnFail", m_autoRetryOnFail},
        {"theme", m_theme},
    };
}
