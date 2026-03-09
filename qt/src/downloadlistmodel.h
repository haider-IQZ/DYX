#pragma once

#include <QAbstractListModel>
#include <QDateTime>

struct DownloadEntry {
    QString id;
    QString filename;
    QString url;
    QString outputPath;
    qint64 size = 0;
    qint64 downloaded = 0;
    qint64 speedBytes = 0;
    QString speedText;
    QString etaText;
    QString status;
    int connections = 8;
    QString fileType;
    QDateTime addedAt;
    QString sizeText;
    QString progressText;
    double progressPercent = 0.0;
    QString statusText;
    QString statusColor;
};

class DownloadListModel final : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString activeFilter READ activeFilter WRITE setActiveFilter NOTIFY activeFilterChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        FilenameRole,
        UrlRole,
        OutputPathRole,
        SizeRole,
        DownloadedRole,
        SpeedBytesRole,
        SpeedTextRole,
        EtaTextRole,
        StatusRole,
        ConnectionsRole,
        FileTypeRole,
        AddedAtRole,
        SizeTextRole,
        ProgressTextRole,
        ProgressPercentRole,
        StatusTextRole,
        StatusColorRole,
    };
    Q_ENUM(Roles)

    explicit DownloadListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int count() const;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString activeFilter() const;
    void setActiveFilter(const QString &filter);

    QString searchQuery() const;
    void setSearchQuery(const QString &query);

    void setItems(const QList<DownloadEntry> &items);
    const QList<DownloadEntry> &visibleItems() const;
    const QList<DownloadEntry> &allItems() const;
    DownloadEntry itemForId(const QString &id) const;
    bool containsId(const QString &id) const;

signals:
    void countChanged();
    void activeFilterChanged();
    void searchQueryChanged();

private:
    void rebuildVisible();
    static bool matchesFilter(const DownloadEntry &item, const QString &filter);

    QList<DownloadEntry> m_allItems;
    QList<DownloadEntry> m_visibleItems;
    QString m_activeFilter = QStringLiteral("all");
    QString m_searchQuery;
};
