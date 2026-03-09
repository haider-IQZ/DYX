#include "backendclient.h"
#include "iconprovider.h"

#include <QApplication>
#include <QDir>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

int main(int argc, char *argv[]) {
    qunsetenv("QT_STYLE_OVERRIDE");
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("DYX"));
    app.setApplicationDisplayName(QStringLiteral("DYX"));
    app.setOrganizationName(QStringLiteral("DYX"));

    BackendClient backend;

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("dyxicon"), new DyxIconProvider());
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("downloadModel"), backend.downloadsModel());
    engine.rootContext()->setContextProperty(QStringLiteral("settingsModel"), backend.settingsModel());

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
