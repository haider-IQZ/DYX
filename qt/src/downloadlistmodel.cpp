#include "downloadlistmodel.h"

#include <algorithm>

namespace {
QString normalized(const QString &value) {
    return value.trimmed().toLower();
}
}

DownloadListModel::DownloadListModel(QObject *parent)
    : QAbstractListModel(parent) {}

int DownloadListModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) {
        return 0;
    }
    return m_visibleItems.size();
}

int DownloadListModel::count() const {
    return m_visibleItems.size();
}

QVariant DownloadListModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_visibleItems.size()) {
        return {};
    }

    const auto &item = m_visibleItems.at(index.row());
    switch (role) {
    case IdRole: return item.id;
    case FilenameRole: return item.filename;
    case UrlRole: return item.url;
    case OutputPathRole: return item.outputPath;
    case SizeRole: return item.size;
    case DownloadedRole: return item.downloaded;
    case SpeedBytesRole: return item.speedBytes;
    case SpeedTextRole: return item.speedText;
    case EtaTextRole: return item.etaText;
    case StatusRole: return item.status;
    case ConnectionsRole: return item.connections;
    case FileTypeRole: return item.fileType;
    case AddedAtRole: return item.addedAt;
    case SizeTextRole: return item.sizeText;
    case ProgressTextRole: return item.progressText;
    case ProgressPercentRole: return item.progressPercent;
    case StatusTextRole: return item.statusText;
    case StatusColorRole: return item.statusColor;
    default: return {};
    }
}

QHash<int, QByteArray> DownloadListModel::roleNames() const {
    return {
        {IdRole, "downloadId"},
        {FilenameRole, "filename"},
        {UrlRole, "url"},
        {OutputPathRole, "outputPath"},
        {SizeRole, "size"},
        {DownloadedRole, "downloaded"},
        {SpeedBytesRole, "speedBytes"},
        {SpeedTextRole, "speedText"},
        {EtaTextRole, "etaText"},
        {StatusRole, "status"},
        {ConnectionsRole, "connections"},
        {FileTypeRole, "fileType"},
        {AddedAtRole, "addedAt"},
        {SizeTextRole, "sizeText"},
        {ProgressTextRole, "progressText"},
        {ProgressPercentRole, "progressPercent"},
        {StatusTextRole, "statusText"},
        {StatusColorRole, "statusColor"},
    };
}

QString DownloadListModel::activeFilter() const {
    return m_activeFilter;
}

void DownloadListModel::setActiveFilter(const QString &filter) {
    if (m_activeFilter == filter) {
        return;
    }
    m_activeFilter = filter;
    rebuildVisible();
    emit activeFilterChanged();
}

QString DownloadListModel::searchQuery() const {
    return m_searchQuery;
}

void DownloadListModel::setSearchQuery(const QString &query) {
    if (m_searchQuery == query) {
        return;
    }
    m_searchQuery = query;
    rebuildVisible();
    emit searchQueryChanged();
}

void DownloadListModel::setItems(const QList<DownloadEntry> &items) {
    m_allItems = items;
    rebuildVisible();
}

const QList<DownloadEntry> &DownloadListModel::visibleItems() const {
    return m_visibleItems;
}

const QList<DownloadEntry> &DownloadListModel::allItems() const {
    return m_allItems;
}

DownloadEntry DownloadListModel::itemForId(const QString &id) const {
    const auto match = std::find_if(m_allItems.begin(), m_allItems.end(), [&](const DownloadEntry &item) {
        return item.id == id;
    });
    return match == m_allItems.end() ? DownloadEntry{} : *match;
}

bool DownloadListModel::containsId(const QString &id) const {
    return std::any_of(m_allItems.begin(), m_allItems.end(), [&](const DownloadEntry &item) {
        return item.id == id;
    });
}

void DownloadListModel::rebuildVisible() {
    QList<DownloadEntry> nextVisible;
    nextVisible.reserve(m_allItems.size());

    const QString query = normalized(m_searchQuery);
    for (const auto &item : m_allItems) {
        if (!matchesFilter(item, m_activeFilter)) {
            continue;
        }
        if (!query.isEmpty() && !item.filename.toLower().contains(query)) {
            continue;
        }
        nextVisible.push_back(item);
    }

    const int previousCount = m_visibleItems.size();

    bool sameRows = nextVisible.size() == m_visibleItems.size();
    if (sameRows) {
        for (int i = 0; i < nextVisible.size(); ++i) {
            if (nextVisible.at(i).id != m_visibleItems.at(i).id) {
                sameRows = false;
                break;
            }
        }
    }

    if (sameRows) {
        m_visibleItems = nextVisible;
        if (!m_visibleItems.isEmpty()) {
            emit dataChanged(index(0, 0), index(m_visibleItems.size() - 1, 0));
        }
        return;
    }

    beginResetModel();
    m_visibleItems = nextVisible;
    endResetModel();

    if (previousCount != m_visibleItems.size()) {
        emit countChanged();
    }
}

bool DownloadListModel::matchesFilter(const DownloadEntry &item, const QString &filter) {
    if (filter == QStringLiteral("all")) return true;
    if (filter == QStringLiteral("downloading")) return item.status == QStringLiteral("downloading");
    if (filter == QStringLiteral("completed")) return item.status == QStringLiteral("completed");
    if (filter == QStringLiteral("queued")) return item.status == QStringLiteral("queued");
    if (filter == QStringLiteral("archives")) return item.fileType == QStringLiteral("archive");
    if (filter == QStringLiteral("videos")) return item.fileType == QStringLiteral("video");
    if (filter == QStringLiteral("audio")) return item.fileType == QStringLiteral("audio");
    if (filter == QStringLiteral("documents")) return item.fileType == QStringLiteral("document");
    return true;
}
