#pragma once

#include <QByteArray>
#include <QHash>
#include <QJsonObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QObject>
#include <functional>

class AppCommandBridge final : public QObject {
    Q_OBJECT

public:
    using CommandHandler = std::function<QJsonObject(const QJsonObject &)>;

    explicit AppCommandBridge(QObject *parent = nullptr);

    bool startListening();
    void setCommandHandler(CommandHandler handler);
    static QJsonObject sendCommandToRunningInstance(const QJsonObject &command, int timeoutMs = 1500);
    static bool isInstanceRunning(int timeoutMs = 250);

private:
    static QString serverName();
    static QByteArray encodeCommand(const QJsonObject &command);
    static QJsonObject decodeCommand(const QByteArray &line);
    static QByteArray encodeResponse(const QJsonObject &response);
    static QJsonObject readResponse(QLocalSocket &socket, int timeoutMs);
    void handleSocket(QLocalSocket *socket);
    QJsonObject dispatchCommand(const QJsonObject &command) const;

    QLocalServer m_server;
    QHash<QLocalSocket *, QByteArray> m_buffers;
    CommandHandler m_commandHandler;
    bool m_newConnectionHooked = false;
};
