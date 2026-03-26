#include "appcommandbridge.h"
#include "firefoxcatcherlog.h"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QProcess>
#include <QThread>

namespace {
bool isRunnableFile(const QString &path) {
    const QFileInfo info(path);
    return info.exists() && info.isFile() && info.isExecutable();
}

QString resolveAppBinary() {
    const QString envBinary = qEnvironmentVariable("DYX_APP_BIN");
    if (!envBinary.isEmpty() && isRunnableFile(envBinary)) {
        return QFileInfo(envBinary).canonicalFilePath();
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        QDir(appDir).filePath(QStringLiteral("../bin/dyx")),
        QDir(appDir).filePath(QStringLiteral("../libexec/dyx-qt")),
        QDir(appDir).filePath(QStringLiteral("../../build/qt/dyx-qt")),
    };

    for (const QString &candidate : candidates) {
        if (isRunnableFile(candidate)) {
            return QFileInfo(candidate).canonicalFilePath();
        }
    }

    return {};
}
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("dyx-relay"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("DYX relay"));
    parser.addHelpOption();

    const QCommandLineOption enqueueUrlOption(
        QStringList{QStringLiteral("enqueue-download-url")},
        QStringLiteral("Queue a download URL into DYX."),
        QStringLiteral("url")
    );
    const QCommandLineOption enqueueSourceOption(
        QStringList{QStringLiteral("enqueue-download-source")},
        QStringLiteral("Source label for an externally queued download."),
        QStringLiteral("source"),
        QStringLiteral("external")
    );
    const QCommandLineOption enqueueFilenameOption(
        QStringList{QStringLiteral("enqueue-download-filename")},
        QStringLiteral("Optional filename hint for an externally queued download."),
        QStringLiteral("filename")
    );
    const QCommandLineOption enqueueSuggestedFilenameOption(
        QStringList{QStringLiteral("enqueue-download-suggested-filename")},
        QStringLiteral("Optional browser-suggested filename for an externally queued download."),
        QStringLiteral("suggested-filename")
    );
    const QCommandLineOption enqueueReferrerOption(
        QStringList{QStringLiteral("enqueue-download-referrer")},
        QStringLiteral("Optional referrer for an externally queued download."),
        QStringLiteral("referrer")
    );
    const QCommandLineOption enqueuePageTitleOption(
        QStringList{QStringLiteral("enqueue-download-page-title")},
        QStringLiteral("Optional page title for an externally queued download."),
        QStringLiteral("page-title")
    );
    const QCommandLineOption enqueueTabUrlOption(
        QStringList{QStringLiteral("enqueue-download-tab-url")},
        QStringLiteral("Optional originating tab URL for an externally queued download."),
        QStringLiteral("tab-url")
    );
    const QCommandLineOption enqueueUserAgentOption(
        QStringList{QStringLiteral("enqueue-download-user-agent")},
        QStringLiteral("Optional user agent for an externally queued download."),
        QStringLiteral("user-agent")
    );
    const QCommandLineOption enqueueRequestMethodOption(
        QStringList{QStringLiteral("enqueue-download-request-method")},
        QStringLiteral("Optional request method for an externally queued download."),
        QStringLiteral("request-method")
    );
    const QCommandLineOption enqueueRequestTypeOption(
        QStringList{QStringLiteral("enqueue-download-request-type")},
        QStringLiteral("Optional Firefox request type for an externally queued download."),
        QStringLiteral("request-type")
    );
    const QCommandLineOption enqueueCorrelationIdOption(
        QStringList{QStringLiteral("enqueue-download-correlation-id")},
        QStringLiteral("Optional correlation id for an externally queued download."),
        QStringLiteral("correlation-id")
    );
    const QCommandLineOption enqueueHeaderOption(
        QStringList{QStringLiteral("enqueue-download-header")},
        QStringLiteral("Optional replay header for an externally queued download. Can be repeated."),
        QStringLiteral("header")
    );

    parser.addOption(enqueueUrlOption);
    parser.addOption(enqueueSourceOption);
    parser.addOption(enqueueFilenameOption);
    parser.addOption(enqueueSuggestedFilenameOption);
    parser.addOption(enqueueReferrerOption);
    parser.addOption(enqueuePageTitleOption);
    parser.addOption(enqueueTabUrlOption);
    parser.addOption(enqueueUserAgentOption);
    parser.addOption(enqueueRequestMethodOption);
    parser.addOption(enqueueRequestTypeOption);
    parser.addOption(enqueueCorrelationIdOption);
    parser.addOption(enqueueHeaderOption);
    parser.process(app);

    if (!parser.isSet(enqueueUrlOption)) {
        qCritical("Missing --enqueue-download-url");
        return 1;
    }

    QJsonObject command{
        {QStringLiteral("type"), QStringLiteral("enqueue_download")},
        {QStringLiteral("url"), parser.value(enqueueUrlOption)},
        {QStringLiteral("source"), parser.value(enqueueSourceOption)},
    };
    if (parser.isSet(enqueueFilenameOption)) {
        command.insert(QStringLiteral("filename"), parser.value(enqueueFilenameOption));
    }
    if (parser.isSet(enqueueSuggestedFilenameOption)) {
        command.insert(QStringLiteral("suggestedFilename"), parser.value(enqueueSuggestedFilenameOption));
    }
    if (parser.isSet(enqueueReferrerOption)) {
        command.insert(QStringLiteral("referrer"), parser.value(enqueueReferrerOption));
    }
    if (parser.isSet(enqueuePageTitleOption)) {
        command.insert(QStringLiteral("pageTitle"), parser.value(enqueuePageTitleOption));
    }
    if (parser.isSet(enqueueTabUrlOption)) {
        command.insert(QStringLiteral("tabUrl"), parser.value(enqueueTabUrlOption));
    }
    if (parser.isSet(enqueueUserAgentOption)) {
        command.insert(QStringLiteral("userAgent"), parser.value(enqueueUserAgentOption));
    }
    if (parser.isSet(enqueueRequestMethodOption)) {
        command.insert(QStringLiteral("requestMethod"), parser.value(enqueueRequestMethodOption));
    }
    if (parser.isSet(enqueueRequestTypeOption)) {
        command.insert(QStringLiteral("requestType"), parser.value(enqueueRequestTypeOption));
    }
    if (parser.isSet(enqueueCorrelationIdOption)) {
        command.insert(QStringLiteral("correlationId"), parser.value(enqueueCorrelationIdOption));
    }
    const QStringList replayHeaders = parser.values(enqueueHeaderOption);
    if (!replayHeaders.isEmpty()) {
        QJsonArray headersArray;
        for (const QString &header : replayHeaders) {
            if (!header.trimmed().isEmpty()) {
                headersArray.append(header.trimmed());
            }
        }
        if (!headersArray.isEmpty()) {
            command.insert(QStringLiteral("headers"), headersArray);
        }
    }

    const auto sendCommand = [&command]() {
        return AppCommandBridge::sendCommandToRunningInstance(command, 1500);
    };

    FirefoxCatcherLog::append(
        QStringLiteral("relay.ndjson"),
        QStringLiteral("relay"),
        QStringLiteral("command_received"),
        command
    );

    QJsonObject response = sendCommand();
    if (response.value(QStringLiteral("ok")).toBool()) {
        FirefoxCatcherLog::append(
            QStringLiteral("relay.ndjson"),
            QStringLiteral("relay"),
            QStringLiteral("bridge_send_succeeded"),
            QJsonObject{
                {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()},
                {QStringLiteral("response"), response}
            }
        );
        return 0;
    }

    FirefoxCatcherLog::append(
        QStringLiteral("relay.ndjson"),
        QStringLiteral("relay"),
        QStringLiteral("bridge_send_failed"),
        QJsonObject{
            {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()},
            {QStringLiteral("response"), response}
        }
    );

    const QString appBinary = resolveAppBinary();
    if (appBinary.isEmpty()) {
        FirefoxCatcherLog::append(
            QStringLiteral("relay.ndjson"),
            QStringLiteral("relay"),
            QStringLiteral("app_binary_not_found"),
            QJsonObject{{QStringLiteral("url"), command.value(QStringLiteral("url")).toString()}}
        );
        qCritical("Could not find DYX app binary for relay launch");
        return 1;
    }

    if (!QProcess::startDetached(appBinary, {})) {
        FirefoxCatcherLog::append(
            QStringLiteral("relay.ndjson"),
            QStringLiteral("relay"),
            QStringLiteral("app_launch_failed"),
            QJsonObject{
                {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()},
                {QStringLiteral("appBinary"), appBinary}
            }
        );
        qCritical("Failed to launch DYX app from relay");
        return 1;
    }

    FirefoxCatcherLog::append(
        QStringLiteral("relay.ndjson"),
        QStringLiteral("relay"),
        QStringLiteral("app_launch_started"),
        QJsonObject{
            {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()},
            {QStringLiteral("appBinary"), appBinary}
        }
    );

    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < 5000) {
        response = sendCommand();
        if (response.value(QStringLiteral("ok")).toBool()) {
            FirefoxCatcherLog::append(
                QStringLiteral("relay.ndjson"),
                QStringLiteral("relay"),
                QStringLiteral("bridge_send_succeeded_after_launch"),
                QJsonObject{
                    {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()},
                    {QStringLiteral("elapsedMs"), static_cast<int>(timer.elapsed())},
                    {QStringLiteral("response"), response}
                }
            );
            return 0;
        }
        QThread::msleep(100);
    }

    const QString errorMessage = response.value(QStringLiteral("error")).toString();
    FirefoxCatcherLog::append(
        QStringLiteral("relay.ndjson"),
        QStringLiteral("relay"),
        QStringLiteral("bridge_send_timed_out"),
        QJsonObject{
            {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()},
            {QStringLiteral("elapsedMs"), static_cast<int>(timer.elapsed())},
            {QStringLiteral("response"), response}
        }
    );
    if (errorMessage.isEmpty()) {
        qCritical("Timed out waiting for DYX to accept relay command");
    } else {
        qCritical("DYX relay command failed: %s", qPrintable(errorMessage));
    }
    return 1;
}
