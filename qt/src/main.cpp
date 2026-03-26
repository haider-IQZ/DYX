#include "appcommandbridge.h"
#include "backendclient.h"
#include "iconprovider.h"
#include "uistate.h"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QIcon>
#include <QJsonArray>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QTimer>

int main(int argc, char *argv[]) {
    qunsetenv("QT_STYLE_OVERRIDE");
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("DYX"));
    app.setApplicationDisplayName(QStringLiteral("DYX"));
    app.setOrganizationName(QStringLiteral("DYX"));
    app.setWindowIcon(QIcon(QStringLiteral(":/icons/resources/branding/dyx-app-icon.png")));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("DYX Download Manager"));
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
    const QCommandLineOption enqueueUserAgentOption(
        QStringList{QStringLiteral("enqueue-download-user-agent")},
        QStringLiteral("Optional user agent for an externally queued download."),
        QStringLiteral("user-agent")
    );
    const QCommandLineOption enqueueHeaderOption(
        QStringList{QStringLiteral("enqueue-download-header")},
        QStringLiteral("Optional header for an externally queued download. May be repeated."),
        QStringLiteral("header")
    );
    const QCommandLineOption enqueueRequestMethodOption(
        QStringList{QStringLiteral("enqueue-download-request-method")},
        QStringLiteral("Original request method for an externally queued download."),
        QStringLiteral("method")
    );
    const QCommandLineOption enqueueRequestTypeOption(
        QStringList{QStringLiteral("enqueue-download-request-type")},
        QStringLiteral("Original request type for an externally queued download."),
        QStringLiteral("request-type")
    );
    const QCommandLineOption enqueueTabUrlOption(
        QStringList{QStringLiteral("enqueue-download-tab-url")},
        QStringLiteral("Originating tab URL for an externally queued download."),
        QStringLiteral("tab-url")
    );
    const QCommandLineOption enqueueCorrelationIdOption(
        QStringList{QStringLiteral("enqueue-download-correlation-id")},
        QStringLiteral("Correlation id for an externally queued download."),
        QStringLiteral("correlation-id")
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

    parser.addOption(enqueueUrlOption);
    parser.addOption(enqueueSourceOption);
    parser.addOption(enqueueFilenameOption);
    parser.addOption(enqueueSuggestedFilenameOption);
    parser.addOption(enqueueUserAgentOption);
    parser.addOption(enqueueHeaderOption);
    parser.addOption(enqueueRequestMethodOption);
    parser.addOption(enqueueRequestTypeOption);
    parser.addOption(enqueueTabUrlOption);
    parser.addOption(enqueueCorrelationIdOption);
    parser.addOption(enqueueReferrerOption);
    parser.addOption(enqueuePageTitleOption);
    parser.process(app);

    QJsonObject startupCommand;
    if (parser.isSet(enqueueUrlOption)) {
        startupCommand.insert(QStringLiteral("type"), QStringLiteral("enqueue_download"));
        startupCommand.insert(QStringLiteral("url"), parser.value(enqueueUrlOption));
        startupCommand.insert(QStringLiteral("source"), parser.value(enqueueSourceOption));
        if (parser.isSet(enqueueFilenameOption)) {
            startupCommand.insert(QStringLiteral("filename"), parser.value(enqueueFilenameOption));
        }
        if (parser.isSet(enqueueSuggestedFilenameOption)) {
            startupCommand.insert(QStringLiteral("suggestedFilename"), parser.value(enqueueSuggestedFilenameOption));
        }
        if (parser.isSet(enqueueUserAgentOption)) {
            startupCommand.insert(QStringLiteral("userAgent"), parser.value(enqueueUserAgentOption));
        }
        if (parser.isSet(enqueueHeaderOption)) {
            startupCommand.insert(QStringLiteral("headers"), QJsonArray::fromStringList(parser.values(enqueueHeaderOption)));
        }
        if (parser.isSet(enqueueRequestMethodOption)) {
            startupCommand.insert(QStringLiteral("requestMethod"), parser.value(enqueueRequestMethodOption));
        }
        if (parser.isSet(enqueueRequestTypeOption)) {
            startupCommand.insert(QStringLiteral("requestType"), parser.value(enqueueRequestTypeOption));
        }
        if (parser.isSet(enqueueTabUrlOption)) {
            startupCommand.insert(QStringLiteral("tabUrl"), parser.value(enqueueTabUrlOption));
        }
        if (parser.isSet(enqueueCorrelationIdOption)) {
            startupCommand.insert(QStringLiteral("correlationId"), parser.value(enqueueCorrelationIdOption));
        }
        if (parser.isSet(enqueueReferrerOption)) {
            startupCommand.insert(QStringLiteral("referrer"), parser.value(enqueueReferrerOption));
        }
        if (parser.isSet(enqueuePageTitleOption)) {
            startupCommand.insert(QStringLiteral("pageTitle"), parser.value(enqueuePageTitleOption));
        }
    }

    if (AppCommandBridge::isInstanceRunning()) {
        if (!startupCommand.isEmpty()) {
            const QJsonObject response = AppCommandBridge::sendCommandToRunningInstance(startupCommand);
            return response.value(QStringLiteral("ok")).toBool() ? 0 : 1;
        }
        return 0;
    }

    AppCommandBridge commandBridge;
    if (!commandBridge.startListening()) {
        if (!startupCommand.isEmpty()) {
            const QJsonObject response = AppCommandBridge::sendCommandToRunningInstance(startupCommand);
            return response.value(QStringLiteral("ok")).toBool() ? 0 : 1;
        }
        return 0;
    }

    BackendClient backend;
    UiState uiState;

    commandBridge.setCommandHandler([&backend](const QJsonObject &command) {
        return backend.handleExternalCommand(command);
    });

    if (!startupCommand.isEmpty()) {
        QTimer::singleShot(0, &backend, [startupCommand, &backend]() {
            backend.enqueueExternalDownload(startupCommand);
        });
    }

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("dyxicon"), new DyxIconProvider());
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("downloadModel"), backend.downloadsModel());
    engine.rootContext()->setContextProperty(QStringLiteral("settingsModel"), backend.settingsModel());
    engine.rootContext()->setContextProperty(QStringLiteral("uiState"), &uiState);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection
    );
    engine.loadFromModule(QStringLiteral("DYX"), QStringLiteral("Main"));

    return app.exec();
}
