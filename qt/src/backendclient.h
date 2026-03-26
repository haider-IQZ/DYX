#pragma once

#include "downloadlistmodel.h"
#include "settingsmodel.h"

#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QProcess>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <functional>
#include <utility>

class BackendClient final : public QObject {
    Q_OBJECT
    Q_PROPERTY(DownloadListModel *downloadsModel READ downloadsModel CONSTANT)
    Q_PROPERTY(SettingsModel *settingsModel READ settingsModel CONSTANT)
    Q_PROPERTY(int activeCount READ activeCount NOTIFY statsChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY statsChanged)
    Q_PROPERTY(QString downloadSpeedText READ downloadSpeedText NOTIFY statsChanged)

public:
    explicit BackendClient(QObject *parent = nullptr);
    ~BackendClient() override;

    DownloadListModel *downloadsModel();
    SettingsModel *settingsModel();

    int activeCount() const;
    int totalCount() const;
    QString downloadSpeedText() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setSearchQuery(const QString &query);
    Q_INVOKABLE void setActiveFilter(const QString &filter);
    Q_INVOKABLE void startDownload(const QString &url, int connections, const QString &savePath, const QString &optionalFilename = QString());
    Q_INVOKABLE void enqueueExternalDownload(const QJsonObject &command);
    QJsonObject handleExternalCommand(const QJsonObject &command);
    Q_INVOKABLE void togglePause(const QString &id);
    Q_INVOKABLE void deleteItem(const QString &id);
    Q_INVOKABLE void openFolder(const QString &id);
    Q_INVOKABLE QString homeDirectory() const;
    Q_INVOKABLE QString normalizeDirectoryPath(const QString &path) const;
    Q_INVOKABLE QString parentDirectory(const QString &path) const;
    Q_INVOKABLE QVariantList listDirectories(const QString &path) const;
    Q_INVOKABLE void saveSettings();

signals:
    void statsChanged();

private:
    using ResponseHandler = std::function<void(const QJsonObject &)>;

    void launchBackend();
    QString resolveBackendBinary() const;
    void handleStdout();
    void handleBackendFinished();
    void handleBackendLine(const QByteArray &line);
    void handleResponse(const QJsonObject &response);
    void handleEvent(const QJsonObject &event);
    QString sendRequestAsync(const QString &method, const QJsonValue &params, ResponseHandler handler);
    QJsonObject sendRequest(const QString &method, const QJsonValue &params = QJsonObject());
    void setErrorMessage(const QString &message);
    void setBackendConnected(bool connected);
    bool pruneMissingHistory(bool notifyBackend);
    void upsertDownload(const QJsonObject &download);
    void rebuildDownloads();
    void updateStats();

    static QString pathBasename(const QString &path);
    static qint64 speedToBytes(const QString &speedText);
    static QString detectFileType(const QString &filename);
    static QString mapStatus(const QString &status);
    static QString statusLabel(const QString &status);
    static QString formatSize(qint64 bytes);
    static QString progressText(double percent);
    static QDateTime parseDateTime(const QJsonValue &value);

    QProcess m_process;
    QByteArray m_stdoutBuffer;
    quint64 m_nextId = 1;
    QHash<QString, QJsonObject> m_responses;
    QHash<QString, ResponseHandler> m_responseHandlers;
    QJsonArray m_downloads;
    QJsonArray m_history;
    QSet<QString> m_pendingDeleteIds;
    QTimer m_historySyncTimer;
    DownloadListModel m_downloadsModel;
    SettingsModel m_settingsModel;
    int m_activeCount = 0;
    int m_totalCount = 0;
    qint64 m_downloadSpeedBytes = 0;
    QString m_errorMessage;
    bool m_backendConnected = false;
};
