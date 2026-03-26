#include "appcommandbridge.h"
#include "firefoxcatcherlog.h"

#include <algorithm>
#include <QDir>
#include <QElapsedTimer>
#include <QJsonDocument>
#include <QStandardPaths>

namespace {
QString serverNameValue() {
    const QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    const QString baseDir = runtimeDir.isEmpty() ? QDir::tempPath() : runtimeDir;
    return QDir(baseDir).filePath(QStringLiteral("dyx-app-command-bridge-v1.sock"));
}
}

AppCommandBridge::AppCommandBridge(QObject *parent)
    : QObject(parent) {}

bool AppCommandBridge::startListening() {
    if (m_server.isListening()) {
        return true;
    }

    if (!m_newConnectionHooked) {
        connect(&m_server, &QLocalServer::newConnection, this, [this]() {
            while (QLocalSocket *socket = m_server.nextPendingConnection()) {
                handleSocket(socket);
            }
        });
        m_newConnectionHooked = true;
    }

    if (m_server.listen(serverName())) {
        FirefoxCatcherLog::append(
            QStringLiteral("app-bridge.ndjson"),
            QStringLiteral("app-bridge"),
            QStringLiteral("listen_started"),
            QJsonObject{{QStringLiteral("serverName"), serverName()}}
        );
        return true;
    }

    QLocalSocket probe;
    probe.connectToServer(serverName(), QIODevice::ReadWrite);
    if (probe.waitForConnected(100)) {
        probe.disconnectFromServer();
        FirefoxCatcherLog::append(
            QStringLiteral("app-bridge.ndjson"),
            QStringLiteral("app-bridge"),
            QStringLiteral("listen_reused_existing"),
            QJsonObject{{QStringLiteral("serverName"), serverName()}}
        );
        return false;
    }

    QLocalServer::removeServer(serverName());
    const bool listening = m_server.listen(serverName());
    FirefoxCatcherLog::append(
        QStringLiteral("app-bridge.ndjson"),
        QStringLiteral("app-bridge"),
        listening ? QStringLiteral("listen_recovered") : QStringLiteral("listen_failed"),
        QJsonObject{
            {QStringLiteral("serverName"), serverName()},
            {QStringLiteral("error"), m_server.errorString()}
        }
    );
    return listening;
}

void AppCommandBridge::setCommandHandler(CommandHandler handler) {
    m_commandHandler = std::move(handler);
}

QJsonObject AppCommandBridge::sendCommandToRunningInstance(const QJsonObject &command, int timeoutMs) {
    QLocalSocket socket;
    socket.connectToServer(serverName(), QIODevice::ReadWrite);
    if (!socket.waitForConnected(timeoutMs)) {
        FirefoxCatcherLog::append(
            QStringLiteral("app-bridge.ndjson"),
            QStringLiteral("app-bridge"),
            QStringLiteral("send_connect_failed"),
            QJsonObject{
                {QStringLiteral("serverName"), serverName()},
                {QStringLiteral("timeoutMs"), timeoutMs},
                {QStringLiteral("type"), command.value(QStringLiteral("type")).toString()},
                {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()},
                {QStringLiteral("error"), socket.errorString()}
            }
        );
        return {};
    }

    const QByteArray payload = encodeCommand(command);
    if (socket.write(payload) != payload.size()) {
        FirefoxCatcherLog::append(
            QStringLiteral("app-bridge.ndjson"),
            QStringLiteral("app-bridge"),
            QStringLiteral("send_write_failed"),
            QJsonObject{
                {QStringLiteral("type"), command.value(QStringLiteral("type")).toString()},
                {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()}
            }
        );
        return {};
    }
    if (!socket.waitForBytesWritten(timeoutMs)) {
        FirefoxCatcherLog::append(
            QStringLiteral("app-bridge.ndjson"),
            QStringLiteral("app-bridge"),
            QStringLiteral("send_flush_failed"),
            QJsonObject{
                {QStringLiteral("type"), command.value(QStringLiteral("type")).toString()},
                {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()},
                {QStringLiteral("timeoutMs"), timeoutMs}
            }
        );
        return {};
    }

    const QJsonObject response = readResponse(socket, timeoutMs);
    FirefoxCatcherLog::append(
        QStringLiteral("app-bridge.ndjson"),
        QStringLiteral("app-bridge"),
        response.value(QStringLiteral("ok")).toBool()
            ? QStringLiteral("send_succeeded")
            : QStringLiteral("send_failed"),
        QJsonObject{
            {QStringLiteral("type"), command.value(QStringLiteral("type")).toString()},
            {QStringLiteral("url"), command.value(QStringLiteral("url")).toString()},
            {QStringLiteral("timeoutMs"), timeoutMs},
            {QStringLiteral("response"), response}
        }
    );
    socket.disconnectFromServer();
    socket.waitForDisconnected(100);
    return response;
}

bool AppCommandBridge::isInstanceRunning(int timeoutMs) {
    QLocalSocket socket;
    socket.connectToServer(serverName(), QIODevice::ReadWrite);
    if (!socket.waitForConnected(timeoutMs)) {
        return false;
    }
    socket.disconnectFromServer();
    socket.waitForDisconnected(100);
    return true;
}

QString AppCommandBridge::serverName() {
    return serverNameValue();
}

QByteArray AppCommandBridge::encodeCommand(const QJsonObject &command) {
    return QJsonDocument(command).toJson(QJsonDocument::Compact) + '\n';
}

QJsonObject AppCommandBridge::decodeCommand(const QByteArray &line) {
    const QJsonDocument document = QJsonDocument::fromJson(line);
    if (!document.isObject()) {
        return {};
    }
    return document.object();
}

QByteArray AppCommandBridge::encodeResponse(const QJsonObject &response) {
    return QJsonDocument(response).toJson(QJsonDocument::Compact) + '\n';
}

QJsonObject AppCommandBridge::readResponse(QLocalSocket &socket, int timeoutMs) {
    QByteArray buffer;
    QElapsedTimer timer;
    timer.start();

    while (timer.elapsed() < timeoutMs) {
        const int newlineIndex = buffer.indexOf('\n');
        if (newlineIndex >= 0) {
            return decodeCommand(buffer.left(newlineIndex).trimmed());
        }

        const int remainingMs = std::max(0, timeoutMs - static_cast<int>(timer.elapsed()));
        if (!socket.bytesAvailable() && !socket.waitForReadyRead(remainingMs)) {
            break;
        }
        buffer.append(socket.readAll());
    }

    const int newlineIndex = buffer.indexOf('\n');
    if (newlineIndex >= 0) {
        return decodeCommand(buffer.left(newlineIndex).trimmed());
    }
    return {};
}

void AppCommandBridge::handleSocket(QLocalSocket *socket) {
    socket->setParent(this);

    connect(socket, &QLocalSocket::readyRead, this, [this, socket]() {
        QByteArray &buffer = m_buffers[socket];
        buffer.append(socket->readAll());

        while (true) {
            const int newlineIndex = buffer.indexOf('\n');
            if (newlineIndex < 0) {
                break;
            }

            const QByteArray line = buffer.left(newlineIndex).trimmed();
            buffer.remove(0, newlineIndex + 1);
            if (line.isEmpty()) {
                continue;
            }

            const QJsonObject command = decodeCommand(line);
            QJsonObject response;
            if (command.isEmpty()) {
                response.insert(QStringLiteral("ok"), false);
                response.insert(QStringLiteral("error"), QStringLiteral("Invalid bridge request."));
            } else {
                response = dispatchCommand(command);
            }

            FirefoxCatcherLog::append(
                QStringLiteral("app-bridge.ndjson"),
                QStringLiteral("app-bridge"),
                response.value(QStringLiteral("ok")).toBool()
                    ? QStringLiteral("incoming_command_accepted")
                    : QStringLiteral("incoming_command_rejected"),
                QJsonObject{
                    {QStringLiteral("command"), command},
                    {QStringLiteral("response"), response}
                }
            );

            socket->write(encodeResponse(response));
            socket->flush();
            socket->waitForBytesWritten(1000);
            socket->disconnectFromServer();
            break;
        }
    });

    connect(socket, &QLocalSocket::disconnected, this, [this, socket]() {
        m_buffers.remove(socket);
        socket->deleteLater();
    });

    connect(socket, &QLocalSocket::errorOccurred, this, [this, socket](QLocalSocket::LocalSocketError) {
        m_buffers.remove(socket);
        socket->deleteLater();
    });
}

QJsonObject AppCommandBridge::dispatchCommand(const QJsonObject &command) const {
    const QString type = command.value(QStringLiteral("type")).toString();
    if (type == QStringLiteral("ping")) {
        return QJsonObject{{QStringLiteral("ok"), true}};
    }

    if (!m_commandHandler) {
        return QJsonObject{
            {QStringLiteral("ok"), false},
            {QStringLiteral("error"), QStringLiteral("No bridge handler configured.")},
        };
    }

    QJsonObject response = m_commandHandler(command);
    if (!response.contains(QStringLiteral("ok"))) {
        response.insert(QStringLiteral("ok"), false);
    }
    return response;
}
