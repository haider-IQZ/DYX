#include "backendclient.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QDir>
#include <QEventLoop>
#include <QFileDialog>
#include <QFileInfo>
#include <QFileInfoList>
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

QString humanStatus(const QString &status) {
    if (status == QStringLiteral("completed")) return QStringLiteral("Completed");
    if (status == QStringLiteral("downloading")) return QStringLiteral("Downloading");
    if (status == QStringLiteral("paused")) return QStringLiteral("Paused");
    if (status == QStringLiteral("error")) return QStringLiteral("Error");
    return QStringLiteral("Queued");
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
QString BackendClient::axelVersion() const { return m_axelVersion; }
bool BackendClient::axelAvailable() const { return m_axelAvailable; }
QString BackendClient::errorMessage() const { return m_errorMessage; }
bool BackendClient::backendConnected() const { return m_backendConnected; }

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
    const auto axelResponse = sendRequest(QStringLiteral("checkAxel"));

    if (downloadsResponse.value("ok").toBool()) {
        m_downloads = downloadsResponse.value("result").toArray();
    }
    if (historyResponse.value("ok").toBool()) {
        m_history = historyResponse.value("result").toArray();
    }
    if (settingsResponse.value("ok").toBool()) {
        m_settingsModel.fromJson(settingsResponse.value("result").toObject());
    }
    if (axelResponse.value("ok").toBool()) {
        const auto status = axelResponse.value("result").toObject();
        m_axelAvailable = status.value("available").toBool(true);
        m_axelVersion = status.value("version").toString(m_axelAvailable ? QStringLiteral("Available") : QStringLiteral("Missing"));
        emit axelStatusChanged();
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

    QString fileName = optionalFilename.trimmed();
    if (fileName.isEmpty()) {
        const auto parsedUrl = QUrl(url);
        fileName = pathBasename(parsedUrl.path());
        if (fileName.isEmpty()) {
            fileName = QStringLiteral("download");
        }
    }

    QString outputPath;
    if (!savePath.trimmed().isEmpty()) {
        outputPath = QDir(savePath.trimmed()).filePath(fileName);
    }

    QJsonObject params{
        {QStringLiteral("url"), url.trimmed()},
        {QStringLiteral("connections"), connections},
    };
    if (!outputPath.isEmpty()) {
        params.insert(QStringLiteral("outputPath"), outputPath);
    }

    const auto response = sendRequest(QStringLiteral("startDownload"), params);
    if (!response.value("ok").toBool()) {
        return;
    }
    refresh();
}

void BackendClient::togglePause(const QString &id) {
    const auto item = m_downloadsModel.itemForId(id);
    if (item.id.isEmpty()) return;

    if (item.status == QStringLiteral("downloading") || item.status == QStringLiteral("queued")) {
        sendRequest(QStringLiteral("cancelDownload"), QJsonObject{{QStringLiteral("id"), id}});
    } else if (item.status == QStringLiteral("paused") || item.status == QStringLiteral("error")) {
        sendRequest(QStringLiteral("retryDownload"), QJsonObject{{QStringLiteral("id"), id}});
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
        m_pendingDeletes.insert(id, item.outputPath);
        sendRequest(QStringLiteral("cancelDownload"), QJsonObject{{QStringLiteral("id"), id}});
        return;
    }

    sendRequest(QStringLiteral("deleteFile"), QJsonObject{{QStringLiteral("path"), item.outputPath}});
    sendRequest(QStringLiteral("removeHistoryItem"), QJsonObject{{QStringLiteral("id"), id}});
}

void BackendClient::openFolder(const QString &id) {
    const auto item = m_downloadsModel.itemForId(id);
    if (item.id.isEmpty()) return;
    sendRequest(QStringLiteral("openFolder"), QJsonObject{{QStringLiteral("path"), item.outputPath}});
}

void BackendClient::openFile(const QString &id) {
    const auto item = m_downloadsModel.itemForId(id);
    if (item.id.isEmpty()) return;
    sendRequest(QStringLiteral("openFile"), QJsonObject{{QStringLiteral("path"), item.outputPath}});
}

QString BackendClient::pickDirectory(const QString &initialPath) {
    const QString selection = QFileDialog::getExistingDirectory(
        nullptr,
        QStringLiteral("Choose Download Folder"),
        initialPath.isEmpty() ? m_settingsModel.defaultDownloadDir() : initialPath
    );
    if (!selection.isEmpty()) {
        emit directoryPicked(selection);
    }
    return selection;
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
    m_responses.insert(response.value(QStringLiteral("id")).toString(), response);
}

void BackendClient::handleEvent(const QJsonObject &event) {
    const QString eventName = event.value(QStringLiteral("event")).toString();
    const auto payload = event.value(QStringLiteral("payload"));

    if (eventName == QStringLiteral("downloadStateChanged")) {
        const auto next = payload.toObject();
        bool replaced = false;
        for (int i = 0; i < m_downloads.size(); ++i) {
            if (m_downloads.at(i).toObject().value(QStringLiteral("id")).toString() == next.value(QStringLiteral("id")).toString()) {
                m_downloads[i] = next;
                replaced = true;
                break;
            }
        }
        if (!replaced) {
            m_downloads.prepend(next);
        }
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
        rebuildDownloads();
        return;
    }

    if (eventName == QStringLiteral("historyChanged")) {
        m_history = payload.toArray();
        for (const auto item : m_history) {
            const auto object = item.toObject();
            const QString id = object.value(QStringLiteral("id")).toString();
            if (!m_pendingDeletes.contains(id)) {
                continue;
            }
            const QString path = m_pendingDeletes.take(id);
            sendRequest(QStringLiteral("deleteFile"), QJsonObject{{QStringLiteral("path"), path}});
            sendRequest(QStringLiteral("removeHistoryItem"), QJsonObject{{QStringLiteral("id"), id}});
        }
        rebuildDownloads();
        return;
    }

    if (eventName == QStringLiteral("axelAvailabilityChanged")) {
        const auto status = payload.toObject();
        m_axelAvailable = status.value(QStringLiteral("available")).toBool(true);
        m_axelVersion = status.value(QStringLiteral("version")).toString(m_axelAvailable ? QStringLiteral("Available") : QStringLiteral("Missing"));
        emit axelStatusChanged();
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
    m_process.waitForBytesWritten();

    QElapsedTimer timer;
    timer.start();
    while (!m_responses.contains(id) && timer.elapsed() < 20000) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
        if (m_process.state() != QProcess::Running) {
            break;
        }
        if (m_process.bytesAvailable() > 0 || m_process.waitForReadyRead(50)) {
            handleStdout();
        }
    }

    const auto response = m_responses.take(id);
    if (response.isEmpty()) {
        setErrorMessage(QStringLiteral("Timed out waiting for backend response to %1").arg(method));
        return {};
    }

    if (!response.value(QStringLiteral("ok")).toBool()) {
        setErrorMessage(response.value(QStringLiteral("error")).toString(QStringLiteral("Backend request failed")));
    } else if (!m_errorMessage.isEmpty()) {
        setErrorMessage({});
    }
    return response;
}

void BackendClient::setErrorMessage(const QString &message) {
    if (m_errorMessage == message) {
        return;
    }
    m_errorMessage = message;
    emit errorMessageChanged();
}

void BackendClient::setBackendConnected(bool connected) {
    if (m_backendConnected == connected) {
        return;
    }
    m_backendConnected = connected;
    emit backendConnectedChanged();
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
        entry.status = mapStatus(object.value(QStringLiteral("status")).toString());
        entry.connections = fallbackConnections;
        entry.fileType = detectFileType(entry.filename);
        entry.addedAt = parseDateTime(object.value(QStringLiteral("startedAt")));
        entry.progressPercent = object.value(QStringLiteral("progressPercent")).toDouble(
            entry.size > 0 ? (100.0 * static_cast<double>(entry.downloaded) / static_cast<double>(entry.size)) : 0.0
        );
        entry.sizeText = QStringLiteral("%1 / %2").arg(formatSize(entry.downloaded), formatSize(entry.size));
        entry.progressText = progressText(entry.progressPercent);
        entry.statusText = statusLabel(entry.status);
        entry.statusColor = statusColor(entry.status);
        next.push_back(entry);
    };

    for (const auto item : m_downloads) {
        appendEntry(item.toObject());
    }

    for (const auto item : m_history) {
        const auto object = item.toObject();
        if (activeOutputPaths.contains(object.value(QStringLiteral("outputPath")).toString())) {
            continue;
        }
        appendEntry(object);
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

QString BackendClient::pathDirname(const QString &path) {
    const QString normalized = path;
    const int slash = std::max(normalized.lastIndexOf('/'), normalized.lastIndexOf('\\'));
    if (slash < 0) return normalized;
    return normalized.left(slash);
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
    if (status == QStringLiteral("cancelled")) return QStringLiteral("paused");
    if (status == QStringLiteral("downloading")) return QStringLiteral("downloading");
    return QStringLiteral("queued");
}

QString BackendClient::statusColor(const QString &status) {
    if (status == QStringLiteral("completed")) return QStringLiteral("#4ade80");
    if (status == QStringLiteral("downloading")) return QStringLiteral("#60a5fa");
    if (status == QStringLiteral("paused")) return QStringLiteral("#fbbf24");
    if (status == QStringLiteral("error")) return QStringLiteral("#f87171");
    return QStringLiteral("#a1a1aa");
}

QString BackendClient::statusLabel(const QString &status) {
    return humanStatus(status);
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
