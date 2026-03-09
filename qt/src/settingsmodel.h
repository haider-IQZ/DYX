#pragma once

#include <QObject>
#include <QJsonObject>

class SettingsModel final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString defaultDownloadDir READ defaultDownloadDir WRITE setDefaultDownloadDir NOTIFY changed)
    Q_PROPERTY(int defaultConnections READ defaultConnections WRITE setDefaultConnections NOTIFY changed)
    Q_PROPERTY(int defaultTimeoutSeconds READ defaultTimeoutSeconds WRITE setDefaultTimeoutSeconds NOTIFY changed)
    Q_PROPERTY(int maxConcurrentDownloads READ maxConcurrentDownloads WRITE setMaxConcurrentDownloads NOTIFY changed)
    Q_PROPERTY(bool defaultNoClobber READ defaultNoClobber WRITE setDefaultNoClobber NOTIFY changed)
    Q_PROPERTY(bool autoRetryOnFail READ autoRetryOnFail WRITE setAutoRetryOnFail NOTIFY changed)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY changed)

public:
    explicit SettingsModel(QObject *parent = nullptr);

    QString defaultDownloadDir() const;
    void setDefaultDownloadDir(const QString &value);

    int defaultConnections() const;
    void setDefaultConnections(int value);

    int defaultTimeoutSeconds() const;
    void setDefaultTimeoutSeconds(int value);

    int maxConcurrentDownloads() const;
    void setMaxConcurrentDownloads(int value);

    bool defaultNoClobber() const;
    void setDefaultNoClobber(bool value);

    bool autoRetryOnFail() const;
    void setAutoRetryOnFail(bool value);

    QString theme() const;
    void setTheme(const QString &value);

    void fromJson(const QJsonObject &json);
    QJsonObject toJson() const;

signals:
    void changed();

private:
    QString m_defaultDownloadDir = QStringLiteral("~/Downloads");
    int m_defaultConnections = 8;
    int m_defaultTimeoutSeconds = 30;
    int m_maxConcurrentDownloads = 4;
    bool m_defaultNoClobber = false;
    bool m_autoRetryOnFail = false;
    QString m_theme = QStringLiteral("dark");
};
