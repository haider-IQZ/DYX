#include "backendclient.h"
#include "firefoxcatcherlog.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QDir>
#include <QEventLoop>
#include <QFileInfo>
#include <QFileInfoList>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonValue>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

namespace {
QString requestId(quint64 nextId) {
    return QStringLiteral("req_%1").arg(nextId);
}

struct ExternalDownloadContext {
    QString url;
    int connections = 0;
    QString savePath;
    QString suggestedFilename;
    QString userAgent;
    QString referrer;
    QString pageTitle;
    QString source;
    QString correlationId;
    bool requiresBrowserAuth = false;
    QStringList headers;
};

QString fallbackFilenameForUrl(const QString &url) {
    const QUrl parsedUrl(url);
    const QString basename = QFileInfo(parsedUrl.path()).fileName().trimmed();
    return basename.isEmpty() ? QStringLiteral("download.bin") : basename;
}

QString sanitizedFilename(QString fileName) {
    fileName = QFileInfo(fileName.trimmed()).fileName().trimmed();
    return fileName.isEmpty() ? QStringLiteral("download.bin") : fileName;
}

bool hasHeaderNamed(const QStringList &headers, const QString &name) {
    const QString normalizedName = name.trimmed().toLower();
    for (const QString &header : headers) {
        const int colonIndex = header.indexOf(':');
        if (colonIndex <= 0) {
            continue;
        }
        if (header.left(colonIndex).trimmed().toLower() == normalizedName) {
            return true;
        }
    }
    return false;
}

QStringList jsonStringList(const QJsonValue &value) {
    QStringList headers;
    const QJsonArray array = value.toArray();
    headers.reserve(array.size());
    for (const QJsonValue &entry : array) {
        const QString header = entry.toString().trimmed();
        if (!header.isEmpty()) {
            headers.push_back(header);
        }
    }
    return headers;
}

QJsonObject buildStartDownloadParams(
    const ExternalDownloadContext &context
) {
    QStringList headers = context.headers;
    if (!context.referrer.trimmed().isEmpty() && !hasHeaderNamed(headers, QStringLiteral("referer"))) {
        headers.push_back(QStringLiteral("Referer: %1").arg(context.referrer.trimmed()));
    }

    const QString fileName = sanitizedFilename(
        context.suggestedFilename.trimmed().isEmpty()
            ? fallbackFilenameForUrl(context.url)
            : context.suggestedFilename
    );

    QString outputPath;
    if (!context.savePath.trimmed().isEmpty()) {
        outputPath = QDir(context.savePath.trimmed()).filePath(fileName);
    }

    QJsonObject params{
        {QStringLiteral("url"), context.url.trimmed()},
        {QStringLiteral("connections"), context.connections},
        {QStringLiteral("suggestedFilename"), fileName},
        {QStringLiteral("correlationId"), context.correlationId.trimmed()},
        {QStringLiteral("requiresBrowserAuth"), context.requiresBrowserAuth},
    };
    if (!outputPath.isEmpty()) {
        params.insert(QStringLiteral("outputPath"), outputPath);
    }
    if (!context.userAgent.trimmed().isEmpty()) {
        params.insert(QStringLiteral("userAgent"), context.userAgent.trimmed());
    }
    if (!headers.isEmpty()) {
        QJsonArray headerArray;
        for (const QString &header : headers) {
            headerArray.append(header);
        }
        params.insert(QStringLiteral("headers"), headerArray);
    }
    return params;
}

QString startDownloadError(const QJsonObject &response) {
    const QString error = response.value(QStringLiteral("error")).toString().trimmed();
    if (error == QStringLiteral("DownloadAlreadyActive")) {
        return QStringLiteral("A download is already active for that target file.");
    }
    if (error == QStringLiteral("FreshBrowserHandoffRequired")) {
        return QStringLiteral("This download needs a fresh browser handoff before DYX can resume it.");
    }
    if (!error.isEmpty()) {
        return error;
    }
    return QStringLiteral("DYX backend did not create the download.");
}
}

BackendClient::BackendClient(QObject *parent)
    : QObject(parent),
      m_downloadsModel(this),
      m_settingsModel(this) {
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &BackendClient::handleStdout);
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this, [this](int, QProcess::ExitStatus) {
        handleBackendFinished();
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
        setErrorMessage(m_process.errorString());
        setBackendConnected(false);
    });
    m_historySyncTimer.setInterval(3000);
    connect(&m_historySyncTimer, &QTimer::timeout, this, [this]() {
        if (pruneMissingHistory(true)) {
            rebuildDownloads();
            updateStats();
        }
    });
    m_historySyncTimer.start();

    launchBackend();
    if (m_backendConnected) {
        refresh();
    }
}

BackendClient::~BackendClient() {
    if (m_process.state() != QProcess::NotRunning) {
        m_process.terminate();
        if (!m_process.waitForFinished(1500)) {
            m_process.kill();
            m_process.waitForFinished(500);
        }
    }
}

DownloadListModel *BackendClient::downloadsModel() { return &m_downloadsModel; }
SettingsModel *BackendClient::settingsModel() { return &m_settingsModel; }
int BackendClient::activeCount() const { return m_activeCount; }
int BackendClient::totalCount() const { return m_totalCount; }
QString BackendClient::downloadSpeedText() const { return formatSize(m_downloadSpeedBytes) + QStringLiteral("/s"); }

void BackendClient::refresh() {
    if (m_process.state() != QProcess::Running) {
        launchBackend();
    }
    if (!m_backendConnected) {
        return;
    }

    const auto downloadsResponse = sendRequest(QStringLiteral("listDownloads"));
    const auto historyResponse = sendRequest(QStringLiteral("listHistory"));
    const auto settingsResponse = sendRequest(QStringLiteral("getSettings"));

    if (downloadsResponse.value("ok").toBool()) {
        m_downloads = downloadsResponse.value("result").toArray();
        QSet<QString> activeIds;
        for (const auto &item : m_downloads) {
            activeIds.insert(item.toObject().value(QStringLiteral("id")).toString());
        }

        for (auto it = m_pendingDeleteIds.begin(); it != m_pendingDeleteIds.end();) {
            if (activeIds.contains(*it)) {
                ++it;
            } else {
                it = m_pendingDeleteIds.erase(it);
            }
        }
    }
    if (historyResponse.value("ok").toBool()) {
        m_history = historyResponse.value("result").toArray();
        pruneMissingHistory(true);
    }
    if (settingsResponse.value("ok").toBool()) {
        m_settingsModel.fromJson(settingsResponse.value("result").toObject());
    }

    rebuildDownloads();
}

void BackendClient::setSearchQuery(const QString &query) {
    m_downloadsModel.setSearchQuery(query);
    updateStats();
}

void BackendClient::setActiveFilter(const QString &filter) {
    m_downloadsModel.setActiveFilter(filter);
    updateStats();
}

void BackendClient::startDownload(const QString &url, int connections, const QString &savePath, const QString &optionalFilename) {
    if (url.trimmed().isEmpty()) {
        return;
    }

    ExternalDownloadContext context;
    context.url = url.trimmed();
    context.connections = connections;
    context.savePath = savePath;
    context.suggestedFilename = optionalFilename;

    const QJsonObject params = buildStartDownloadParams(context);

    sendRequestAsync(QStringLiteral("startDownload"), params, [this](const QJsonObject &response) {
        if (!response.value(QStringLiteral("ok")).toBool()) {
            setErrorMessage(startDownloadError(response));
            return;
        }

        const auto created = response.value(QStringLiteral("result")).toObject();
        if (created.isEmpty()) {
            setErrorMessage(QStringLiteral("DYX backend did not return a created download."));
            return;
        }

        upsertDownload(created);
        rebuildDownloads();
    });
}

void BackendClient::enqueueExternalDownload(const QJsonObject &command) {
    FirefoxCatcherLog::append(
        QStringLiteral("backend-external.ndjson"),
        QStringLiteral("backend"),
        QStringLiteral("external_enqueue_received"),
        command
    );
    const QJsonObject response = handleExternalCommand(command);
    if (!response.value(QStringLiteral("ok")).toBool()) {
        FirefoxCatcherLog::append(
            QStringLiteral("backend-external.ndjson"),
            QStringLiteral("backend"),
            QStringLiteral("external_enqueue_failed"),
            QJsonObject{
                {QStringLiteral("command"), command},
                {QStringLiteral("response"), response}
            }
        );
        setErrorMessage(response.value(QStringLiteral("error")).toString());
        return;
    }
    FirefoxCatcherLog::append(
        QStringLiteral("backend-external.ndjson"),
        QStringLiteral("backend"),
        QStringLiteral("external_enqueue_accepted"),
        QJsonObject{
            {QStringLiteral("command"), command},
            {QStringLiteral("response"), response}
        }
    );
}

QJsonObject BackendClient::handleExternalCommand(const QJsonObject &command) {
    const QString type = command.value(QStringLiteral("type")).toString();
    if (type != QStringLiteral("enqueue_download")) {
        return QJsonObject{
            {QStringLiteral("ok"), false},
            {QStringLiteral("error"), QStringLiteral("Unsupported external command.")},
        };
    }

    const QString url = command.value(QStringLiteral("url")).toString().trimmed();
    const QUrl parsedUrl(url);
    if (url.isEmpty() || !parsedUrl.isValid() || (parsedUrl.scheme() != QStringLiteral("http") && parsedUrl.scheme() != QStringLiteral("https"))) {
        return QJsonObject{
            {QStringLiteral("ok"), false},
            {QStringLiteral("error"), QStringLiteral("Ignored invalid external download request.")},
        };
    }

    if (m_process.state() != QProcess::Running) {
        launchBackend();
    }
    if (m_process.state() != QProcess::Running) {
        return QJsonObject{
            {QStringLiteral("ok"), false},
            {QStringLiteral("error"), QStringLiteral("DYX backend is not available.")},
        };
    }

    ExternalDownloadContext context;
    context.url = url;
    context.connections = m_settingsModel.defaultConnections();
    context.savePath = !m_settingsModel.defaultDownloadDir().trimmed().isEmpty()
        ? m_settingsModel.defaultDownloadDir().trimmed()
        : QDir::homePath();
    context.suggestedFilename = command.value(QStringLiteral("suggestedFilename")).toString().trimmed();
    if (context.suggestedFilename.isEmpty()) {
        context.suggestedFilename = command.value(QStringLiteral("filename")).toString().trimmed();
    }
    context.userAgent = command.value(QStringLiteral("userAgent")).toString().trimmed();
    context.referrer = command.value(QStringLiteral("referrer")).toString().trimmed();
    context.pageTitle = command.value(QStringLiteral("pageTitle")).toString().trimmed();
    context.source = command.value(QStringLiteral("source")).toString().trimmed();
    context.correlationId = command.value(QStringLiteral("correlationId")).toString().trimmed();
    context.headers = jsonStringList(command.value(QStringLiteral("headers")));
    context.requiresBrowserAuth = command.value(QStringLiteral("requiresBrowserAuth")).toBool(
        hasHeaderNamed(context.headers, QStringLiteral("cookie"))
            || hasHeaderNamed(context.headers, QStringLiteral("authorization"))
    );

    FirefoxCatcherLog::append(
        QStringLiteral("backend-external.ndjson"),
        QStringLiteral("backend"),
        QStringLiteral("external_enqueue_validated"),
        QJsonObject{
            {QStringLiteral("url"), url},
            {QStringLiteral("source"), context.source},
            {QStringLiteral("correlationId"), context.correlationId},
            {QStringLiteral("filenamePresent"), !context.suggestedFilename.isEmpty()},
            {QStringLiteral("referrerPresent"), !context.referrer.isEmpty()},
            {QStringLiteral("pageTitlePresent"), !context.pageTitle.isEmpty()},
            {QStringLiteral("userAgentPresent"), !context.userAgent.isEmpty()},
            {QStringLiteral("headerCount"), context.headers.size()},
            {QStringLiteral("requiresBrowserAuth"), context.requiresBrowserAuth},
            {QStringLiteral("savePath"), context.savePath},
            {QStringLiteral("connections"), context.connections}
        }
    );
    const QJsonObject params = buildStartDownloadParams(context);
    const QJsonObject response = sendRequest(QStringLiteral("startDownload"), params);
    if (!response.value(QStringLiteral("ok")).toBool()) {
        FirefoxCatcherLog::append(
            QStringLiteral("backend-external.ndjson"),
            QStringLiteral("backend"),
            QStringLiteral("external_enqueue_backend_rejected"),
            QJsonObject{
                {QStringLiteral("url"), url},
                {QStringLiteral("response"), response}
            }
        );
        return QJsonObject{
            {QStringLiteral("ok"), false},
            {QStringLiteral("error"), startDownloadError(response)},
        };
    }

    const QJsonObject created = response.value(QStringLiteral("result")).toObject();
    if (created.isEmpty() || created.value(QStringLiteral("id")).toString().isEmpty()) {
        FirefoxCatcherLog::append(
            QStringLiteral("backend-external.ndjson"),
            QStringLiteral("backend"),
            QStringLiteral("external_enqueue_backend_empty_result"),
            QJsonObject{
                {QStringLiteral("url"), url},
                {QStringLiteral("response"), response}
            }
        );
        return QJsonObject{
            {QStringLiteral("ok"), false},
            {QStringLiteral("error"), QStringLiteral("DYX backend did not create the download.")},
        };
    }

    upsertDownload(created);
    rebuildDownloads();
    FirefoxCatcherLog::append(
        QStringLiteral("backend-external.ndjson"),
        QStringLiteral("backend"),
        QStringLiteral("external_enqueue_backend_created"),
        QJsonObject{
            {QStringLiteral("url"), url},
            {QStringLiteral("correlationId"), context.correlationId},
            {QStringLiteral("downloadId"), created.value(QStringLiteral("id")).toString()},
            {QStringLiteral("status"), created.value(QStringLiteral("status")).toString()}
        }
    );

    return QJsonObject{
        {QStringLiteral("ok"), true},
        {QStringLiteral("downloadId"), created.value(QStringLiteral("id")).toString()},
        {QStringLiteral("correlationId"), context.correlationId}
    };
}

void BackendClient::togglePause(const QString &id) {
    const auto item = m_downloadsModel.itemForId(id);
    if (item.id.isEmpty()) return;

    if (item.status == QStringLiteral("downloading") || item.status == QStringLiteral("queued")) {
        const auto response = sendRequest(QStringLiteral("pauseDownload"), QJsonObject{{QStringLiteral("id"), id}});
        if (!response.value(QStringLiteral("ok")).toBool()) {
            setErrorMessage(startDownloadError(response));
        }
    } else if (item.status == QStringLiteral("paused")) {
        const auto response = sendRequest(QStringLiteral("resumeDownload"), QJsonObject{{QStringLiteral("id"), id}});
        if (!response.value(QStringLiteral("ok")).toBool()) {
            setErrorMessage(startDownloadError(response));
        }
    } else if (item.status == QStringLiteral("error")) {
        const auto response = sendRequest(QStringLiteral("retryDownload"), QJsonObject{{QStringLiteral("id"), id}});
        if (!response.value(QStringLiteral("ok")).toBool()) {
            setErrorMessage(startDownloadError(response));
        }
    }
}

void BackendClient::deleteItem(const QString &id) {
    const auto item = m_downloadsModel.itemForId(id);
    if (item.id.isEmpty()) return;

    bool isActive = false;
    for (const auto value : m_downloads) {
        const auto object = value.toObject();
        if (object.value(QStringLiteral("id")).toString() == id) {
            isActive = true;
            break;
        }
    }

    if (isActive) {
        const auto response = sendRequest(QStringLiteral("deleteDownload"), QJsonObject{{QStringLiteral("id"), id}});
        if (!response.value(QStringLiteral("ok")).toBool()) {
            return;
        }

        if (response.value(QStringLiteral("result")).toObject().value(QStringLiteral("deleted")).toBool()) {
            m_pendingDeleteIds.insert(id);
            rebuildDownloads();
            updateStats();
        } else {
            setErrorMessage(QStringLiteral("Could not delete download right now."));
        }
        return;
    }

    sendRequest(QStringLiteral("deleteFile"), QJsonObject{{QStringLiteral("path"), item.outputPath}});
    const auto response = sendRequest(QStringLiteral("removeHistoryByPath"), QJsonObject{{QStringLiteral("path"), item.outputPath}});
    if (!response.value(QStringLiteral("ok")).toBool()) {
        return;
    }

    if (response.value(QStringLiteral("result")).toObject().value(QStringLiteral("removed")).toInt() > 0) {
        QJsonArray filtered;
        for (const auto &value : m_history) {
            const auto object = value.toObject();
            if (object.value(QStringLiteral("outputPath")).toString() != item.outputPath) {
                filtered.append(object);
            }
        }
        m_history = filtered;
        rebuildDownloads();
        updateStats();
    }
}

void BackendClient::openFolder(const QString &id) {
    const auto item = m_downloadsModel.itemForId(id);
    if (item.id.isEmpty()) return;
    sendRequest(QStringLiteral("openFolder"), QJsonObject{{QStringLiteral("path"), item.outputPath}});
}

QString BackendClient::homeDirectory() const {
    return QDir::homePath();
}

QString BackendClient::normalizeDirectoryPath(const QString &path) const {
    const QString trimmed = path.trimmed();
    const QString fallback = !m_settingsModel.defaultDownloadDir().trimmed().isEmpty()
        ? m_settingsModel.defaultDownloadDir().trimmed()
        : QDir::homePath();

    auto normalizedExistingDir = [](const QString &candidate) -> QString {
        const QFileInfo info(candidate);
        if (!info.exists() || !info.isDir()) {
            return {};
        }
        const QString canonical = info.canonicalFilePath();
        return canonical.isEmpty() ? QDir::cleanPath(info.absoluteFilePath()) : canonical;
    };

    if (trimmed.isEmpty()) {
        return normalizedExistingDir(fallback);
    }

    if (const QString exact = normalizedExistingDir(trimmed); !exact.isEmpty()) {
        return exact;
    }

    const QFileInfo parentInfo(QFileInfo(trimmed).absolutePath());
    if (parentInfo.exists() && parentInfo.isDir()) {
        const QString canonical = parentInfo.canonicalFilePath();
        return canonical.isEmpty() ? QDir::cleanPath(parentInfo.absoluteFilePath()) : canonical;
    }

    return normalizedExistingDir(fallback);
}

QString BackendClient::parentDirectory(const QString &path) const {
    QDir dir(normalizeDirectoryPath(path));
    if (!dir.cdUp()) {
        return dir.path();
    }
    return dir.path();
}

QVariantList BackendClient::listDirectories(const QString &path) const {
    const QDir dir(normalizeDirectoryPath(path));
    const QFileInfoList entries = dir.entryInfoList(
        QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable,
        QDir::Name | QDir::IgnoreCase
    );

    QVariantList result;
    result.reserve(entries.size());
    for (const QFileInfo &entry : entries) {
        QVariantMap item;
        item.insert(QStringLiteral("name"), entry.fileName());
        item.insert(QStringLiteral("path"), entry.canonicalFilePath().isEmpty() ? entry.absoluteFilePath() : entry.canonicalFilePath());
        result.push_back(item);
    }
    return result;
}

void BackendClient::saveSettings() {
    sendRequest(QStringLiteral("saveSettings"), m_settingsModel.toJson());
}

void BackendClient::launchBackend() {
    if (m_process.state() != QProcess::NotRunning) {
        return;
    }

    const QString backendBinary = resolveBackendBinary();
    if (backendBinary.isEmpty()) {
        setErrorMessage(QStringLiteral("Could not find dyx-backend. Build the Zig backend first."));
        return;
    }

    m_process.setProgram(backendBinary);
    m_process.setProcessChannelMode(QProcess::SeparateChannels);
    m_process.start();
    if (!m_process.waitForStarted(5000)) {
        setErrorMessage(QStringLiteral("Failed to start dyx-backend: %1").arg(m_process.errorString()));
        return;
    }
    setBackendConnected(true);
}

QString BackendClient::resolveBackendBinary() const {
    const QString envBinary = qEnvironmentVariable("DYX_BACKEND_BIN");
    if (!envBinary.isEmpty() && QFileInfo::exists(envBinary)) {
        return envBinary;
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        QDir(appDir).filePath(QStringLiteral("dyx-backend")),
        QDir(appDir).filePath(QStringLiteral("../libexec/dyx-backend")),
        QDir::current().filePath(QStringLiteral("zig-out/bin/dyx-backend")),
        QDir::current().filePath(QStringLiteral("zig-out/bin/dyx")),
    };

    for (const auto &candidate : candidates) {
        if (QFileInfo::exists(candidate)) {
            return QFileInfo(candidate).canonicalFilePath();
        }
    }
    return {};
}

void BackendClient::handleStdout() {
    m_stdoutBuffer.append(m_process.readAllStandardOutput());

    while (true) {
        const int newlineIndex = m_stdoutBuffer.indexOf('\n');
        if (newlineIndex < 0) {
            break;
        }

        const QByteArray line = m_stdoutBuffer.left(newlineIndex).trimmed();
        m_stdoutBuffer.remove(0, newlineIndex + 1);
        if (line.isEmpty()) {
            continue;
        }
        handleBackendLine(line);
    }
}

void BackendClient::handleBackendFinished() {
    m_responses.clear();
    m_responseHandlers.clear();
    setBackendConnected(false);
}

void BackendClient::handleBackendLine(const QByteArray &line) {
    const auto document = QJsonDocument::fromJson(line);
    if (!document.isObject()) {
        return;
    }

    const auto object = document.object();
    if (object.contains(QStringLiteral("event"))) {
        handleEvent(object);
        return;
    }
    handleResponse(object);
}

void BackendClient::handleResponse(const QJsonObject &response) {
    const QString id = response.value(QStringLiteral("id")).toString();
    if (id.isEmpty()) {
        return;
    }

    auto handlerIt = m_responseHandlers.find(id);
    if (handlerIt != m_responseHandlers.end()) {
        auto handler = std::move(handlerIt.value());
        m_responseHandlers.erase(handlerIt);
        handler(response);
        return;
    }

    m_responses.insert(id, response);
}

void BackendClient::handleEvent(const QJsonObject &event) {
    const QString eventName = event.value(QStringLiteral("event")).toString();
    const auto payload = event.value(QStringLiteral("payload"));

    if (eventName == QStringLiteral("downloadStateChanged")) {
        const auto next = payload.toObject();
        upsertDownload(next);
        rebuildDownloads();
        return;
    }

    if (eventName == QStringLiteral("downloadRemoved")) {
        const QString id = payload.toObject().value(QStringLiteral("id")).toString();
        QJsonArray filtered;
        for (const auto item : m_downloads) {
            if (item.toObject().value(QStringLiteral("id")).toString() != id) {
                filtered.append(item);
            }
        }
        m_downloads = filtered;
        m_pendingDeleteIds.remove(id);
        rebuildDownloads();
        return;
    }

    if (eventName == QStringLiteral("historyChanged")) {
        m_history = payload.toArray();
        pruneMissingHistory(false);
        rebuildDownloads();
        return;
    }

    if (eventName == QStringLiteral("axelAvailabilityChanged")) {
        return;
    }

    if (eventName == QStringLiteral("settingsChanged")) {
        m_settingsModel.fromJson(payload.toObject());
    }
}

QJsonObject BackendClient::sendRequest(const QString &method, const QJsonValue &params) {
    if (m_process.state() != QProcess::Running) {
        launchBackend();
    }
    if (m_process.state() != QProcess::Running) {
        return {};
    }

    const QString id = requestId(m_nextId++);
    QJsonObject request{
        {QStringLiteral("id"), id},
        {QStringLiteral("method"), method},
        {QStringLiteral("params"), params.isUndefined() ? QJsonObject{} : params},
    };

    const QByteArray line = QJsonDocument(request).toJson(QJsonDocument::Compact) + '\n';
    m_process.write(line);

    QElapsedTimer timer;
    timer.start();
    while (!m_responses.contains(id) && timer.elapsed() < 20000) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
        if (m_process.state() != QProcess::Running) {
            break;
        }
        if (m_process.bytesAvailable() > 0 || m_process.waitForReadyRead(10)) {
            handleStdout();
        }
    }

    const auto response = m_responses.take(id);
    return response;
}

QString BackendClient::sendRequestAsync(const QString &method, const QJsonValue &params, ResponseHandler handler) {
    if (m_process.state() != QProcess::Running) {
        launchBackend();
    }
    if (m_process.state() != QProcess::Running) {
        return {};
    }

    const QString id = requestId(m_nextId++);
    QJsonObject request{
        {QStringLiteral("id"), id},
        {QStringLiteral("method"), method},
        {QStringLiteral("params"), params.isUndefined() ? QJsonObject{} : params},
    };

    if (handler) {
        m_responseHandlers.insert(id, std::move(handler));
    }

    const QByteArray line = QJsonDocument(request).toJson(QJsonDocument::Compact) + '\n';
    m_process.write(line);
    return id;
}

void BackendClient::setErrorMessage(const QString &message) {
    m_errorMessage = message;
}

void BackendClient::setBackendConnected(bool connected) {
    m_backendConnected = connected;
}

bool BackendClient::pruneMissingHistory(bool notifyBackend) {
    if (m_history.isEmpty()) {
        return false;
    }

    QJsonArray filtered;
    QSet<QString> missingCompletedPaths;

    for (const auto &item : m_history) {
        const auto object = item.toObject();
        const QString status = object.value(QStringLiteral("status")).toString();
        const QString outputPath = object.value(QStringLiteral("outputPath")).toString();
        const bool shouldPrune = status == QStringLiteral("completed")
            && !outputPath.isEmpty()
            && !QFileInfo::exists(outputPath);

        if (shouldPrune) {
            missingCompletedPaths.insert(outputPath);
            continue;
        }

        filtered.append(object);
    }

    if (missingCompletedPaths.isEmpty()) {
        return false;
    }

    m_history = filtered;

    if (notifyBackend) {
        for (const auto &path : missingCompletedPaths) {
            sendRequest(QStringLiteral("removeHistoryByPath"), QJsonObject{{QStringLiteral("path"), path}});
        }
    }

    return true;
}

void BackendClient::upsertDownload(const QJsonObject &download) {
    const QString id = download.value(QStringLiteral("id")).toString();
    if (id.isEmpty()) {
        return;
    }

    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads.at(i).toObject().value(QStringLiteral("id")).toString() == id) {
            m_downloads[i] = download;
            return;
        }
    }

    m_downloads.prepend(download);
}

void BackendClient::rebuildDownloads() {
    QList<DownloadEntry> next;
    const int fallbackConnections = m_settingsModel.defaultConnections();

    QSet<QString> activeOutputPaths;
    for (const auto item : m_downloads) {
        activeOutputPaths.insert(item.toObject().value(QStringLiteral("outputPath")).toString());
    }

    auto appendEntry = [&](const QJsonObject &object) {
        DownloadEntry entry;
        entry.id = object.value(QStringLiteral("id")).toString();
        entry.url = object.value(QStringLiteral("url")).toString();
        entry.outputPath = object.value(QStringLiteral("outputPath")).toString();
        entry.filename = pathBasename(entry.outputPath.isEmpty() ? entry.url : entry.outputPath);
        entry.size = static_cast<qint64>(object.value(QStringLiteral("totalBytes")).toDouble(0));
        const auto downloadedValue = object.value(QStringLiteral("downloadedBytes"));
        if (!downloadedValue.isUndefined() && !downloadedValue.isNull()) {
            entry.downloaded = static_cast<qint64>(downloadedValue.toDouble(0));
        } else if (entry.size > 0) {
            entry.downloaded = static_cast<qint64>((object.value(QStringLiteral("progressPercent")).toDouble(0) / 100.0) * entry.size);
        }
        entry.speedText = object.value(QStringLiteral("speedText")).toString();
        entry.etaText = object.value(QStringLiteral("etaText")).toString();
        entry.speedBytes = speedToBytes(entry.speedText);
        const QString backendStatus = object.value(QStringLiteral("status")).toString();
        const bool needsBrowserAuth = object.value(QStringLiteral("needsBrowserAuth")).toBool(false);
        entry.status = mapStatus(backendStatus);
        entry.connections = fallbackConnections;
        entry.fileType = detectFileType(entry.filename);
        entry.addedAt = parseDateTime(object.value(QStringLiteral("startedAt")));
        entry.progressPercent = object.value(QStringLiteral("progressPercent")).toDouble(
            entry.size > 0 ? (100.0 * static_cast<double>(entry.downloaded) / static_cast<double>(entry.size)) : 0.0
        );
        entry.sizeText = QStringLiteral("%1 / %2").arg(formatSize(entry.downloaded), formatSize(entry.size));
        entry.progressText = progressText(entry.progressPercent);
        entry.statusText = needsBrowserAuth && backendStatus == QStringLiteral("paused")
            ? QStringLiteral("Needs Browser Handoff")
            : statusLabel(backendStatus);
        next.push_back(entry);
    };

    for (const auto item : m_downloads) {
        const auto object = item.toObject();
        if (m_pendingDeleteIds.contains(object.value(QStringLiteral("id")).toString())) {
            continue;
        }
        appendEntry(object);
    }

    QHash<QString, QJsonObject> latestHistoryByOutputPath;
    for (const auto item : m_history) {
        const auto object = item.toObject();
        const QString outputPath = object.value(QStringLiteral("outputPath")).toString();
        if (activeOutputPaths.contains(outputPath)) {
            continue;
        }

        const auto existing = latestHistoryByOutputPath.constFind(outputPath);
        if (existing == latestHistoryByOutputPath.constEnd()) {
            latestHistoryByOutputPath.insert(outputPath, object);
            continue;
        }

        const QDateTime nextStartedAt = parseDateTime(object.value(QStringLiteral("startedAt")));
        const QDateTime existingStartedAt = parseDateTime(existing.value().value(QStringLiteral("startedAt")));
        if (nextStartedAt >= existingStartedAt) {
            latestHistoryByOutputPath.insert(outputPath, object);
        }
    }

    for (auto it = latestHistoryByOutputPath.cbegin(); it != latestHistoryByOutputPath.cend(); ++it) {
        appendEntry(it.value());
    }

    std::sort(next.begin(), next.end(), [](const DownloadEntry &lhs, const DownloadEntry &rhs) {
        return lhs.addedAt > rhs.addedAt;
    });

    m_downloadsModel.setItems(next);
    updateStats();
}

void BackendClient::updateStats() {
    int active = 0;
    qint64 totalSpeed = 0;
    const auto items = m_downloadsModel.allItems();
    const int total = items.size();

    for (const auto &item : items) {
        if (item.status == QStringLiteral("downloading")) {
            ++active;
            totalSpeed += item.speedBytes;
        }
    }

    if (m_activeCount != active || m_totalCount != total || m_downloadSpeedBytes != totalSpeed) {
        m_activeCount = active;
        m_totalCount = total;
        m_downloadSpeedBytes = totalSpeed;
        emit statsChanged();
    }
}

QString BackendClient::pathBasename(const QString &path) {
    const QString normalized = path;
    const int slash = std::max(normalized.lastIndexOf('/'), normalized.lastIndexOf('\\'));
    if (slash < 0) return normalized;
    return normalized.mid(slash + 1);
}

qint64 BackendClient::speedToBytes(const QString &speedText) {
    static const QRegularExpression pattern(QStringLiteral(R"(^\s*([\d.]+)\s*([KMG]?B)\/s\s*$)"), QRegularExpression::CaseInsensitiveOption);
    const auto match = pattern.match(speedText);
    if (!match.hasMatch()) {
        return 0;
    }
    const double value = match.captured(1).toDouble();
    const QString unit = match.captured(2).toUpper();
    qint64 factor = 1;
    if (unit == QStringLiteral("KB")) factor = 1024;
    else if (unit == QStringLiteral("MB")) factor = 1024 * 1024;
    else if (unit == QStringLiteral("GB")) factor = 1024ll * 1024ll * 1024ll;
    return static_cast<qint64>(value * static_cast<double>(factor));
}

QString BackendClient::detectFileType(const QString &filename) {
    const QString ext = QFileInfo(filename).suffix().toLower();
    if (QStringList{QStringLiteral("mp4"), QStringLiteral("mkv"), QStringLiteral("avi"), QStringLiteral("mov"), QStringLiteral("webm")}.contains(ext)) return QStringLiteral("video");
    if (QStringList{QStringLiteral("mp3"), QStringLiteral("wav"), QStringLiteral("flac"), QStringLiteral("aac"), QStringLiteral("ogg")}.contains(ext)) return QStringLiteral("audio");
    if (QStringList{QStringLiteral("jpg"), QStringLiteral("jpeg"), QStringLiteral("png"), QStringLiteral("gif"), QStringLiteral("webp"), QStringLiteral("svg")}.contains(ext)) return QStringLiteral("image");
    if (QStringList{QStringLiteral("pdf"), QStringLiteral("doc"), QStringLiteral("docx"), QStringLiteral("txt"), QStringLiteral("csv"), QStringLiteral("xlsx"), QStringLiteral("pptx")}.contains(ext)) return QStringLiteral("document");
    if (QStringList{QStringLiteral("zip"), QStringLiteral("rar"), QStringLiteral("7z"), QStringLiteral("tar"), QStringLiteral("gz"), QStringLiteral("bz2"), QStringLiteral("xz"), QStringLiteral("iso"), QStringLiteral("dmg"), QStringLiteral("bin")}.contains(ext)) return QStringLiteral("archive");
    return QStringLiteral("other");
}

QString BackendClient::mapStatus(const QString &status) {
    if (status == QStringLiteral("completed")) return QStringLiteral("completed");
    if (status == QStringLiteral("failed")) return QStringLiteral("error");
    if (status == QStringLiteral("paused")) return QStringLiteral("paused");
    if (status == QStringLiteral("cancelled")) return QStringLiteral("cancelled");
    if (status == QStringLiteral("starting")) return QStringLiteral("downloading");
    if (status == QStringLiteral("downloading")) return QStringLiteral("downloading");
    return QStringLiteral("queued");
}

QString BackendClient::statusLabel(const QString &status) {
    if (status == QStringLiteral("completed")) return QStringLiteral("Completed");
    if (status == QStringLiteral("starting")) return QStringLiteral("Starting");
    if (status == QStringLiteral("downloading")) return QStringLiteral("Downloading");
    if (status == QStringLiteral("paused")) return QStringLiteral("Paused");
    if (status == QStringLiteral("failed")) return QStringLiteral("Error");
    if (status == QStringLiteral("cancelled")) return QStringLiteral("Cancelled");
    if (status == QStringLiteral("error")) return QStringLiteral("Error");
    return QStringLiteral("Queued");
}

QString BackendClient::formatSize(qint64 bytes) {
    if (bytes <= 0) return QStringLiteral("0 B");
    static const char *units[] = {"B", "KB", "MB", "GB", "TB"};
    double size = static_cast<double>(bytes);
    int unitIndex = 0;
    while (size >= 1024.0 && unitIndex < 4) {
        size /= 1024.0;
        ++unitIndex;
    }
    const int precision = unitIndex == 0 ? 0 : (size >= 10.0 ? 1 : 2);
    return QStringLiteral("%1 %2").arg(QString::number(size, 'f', precision), units[unitIndex]);
}

QString BackendClient::progressText(double percent) {
    return QStringLiteral("%1%").arg(QString::number(percent, 'f', 1));
}

QDateTime BackendClient::parseDateTime(const QJsonValue &value) {
    if (value.isString()) {
        const auto parsed = QDateTime::fromString(value.toString(), Qt::ISODate);
        if (parsed.isValid()) return parsed;
    }
    if (value.isDouble()) {
        return QDateTime::fromSecsSinceEpoch(static_cast<qint64>(value.toDouble()));
    }
    return QDateTime::currentDateTimeUtc();
}
