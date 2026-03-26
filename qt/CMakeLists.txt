cmake_minimum_required(VERSION 3.21)

project(dyx-qt LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2 Svg)

qt_standard_project_setup(REQUIRES 6.5)

set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qmlcache)

set_source_files_properties(
    qml/theme/Colors.qml
    qml/theme/Spacing.qml
    qml/theme/Typography.qml
    qml/theme/Tokens.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_executable(dyx-qt
    src/main.cpp
    src/appcommandbridge.cpp
    src/backendclient.cpp
    src/downloadlistmodel.cpp
    src/firefoxcatcherlog.cpp
    src/iconprovider.cpp
    src/settingsmodel.cpp
    src/uistate.cpp
)

target_include_directories(dyx-qt PRIVATE src)

target_link_libraries(dyx-qt
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Network
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Svg
)

qt_add_executable(dyx-relay
    src/relaymain.cpp
    src/appcommandbridge.cpp
    src/firefoxcatcherlog.cpp
)

target_include_directories(dyx-relay PRIVATE src)

target_link_libraries(dyx-relay
    PRIVATE
        Qt6::Core
        Qt6::Network
)

qt_add_resources(dyx-qt dyx_icons
    PREFIX "/icons"
    FILES
        resources/branding/dyx-app-icon.png
        resources/icons/activity.svg
        resources/icons/archive.svg
        resources/icons/arrowdown.svg
        resources/icons/audio.svg
        resources/icons/check.svg
        resources/icons/clock.svg
        resources/icons/close.svg
        resources/icons/document.svg
        resources/icons/download.svg
        resources/icons/file.svg
        resources/icons/folder-open.svg
        resources/icons/gear.svg
        resources/icons/harddrive.svg
        resources/icons/image.svg
        resources/icons/infinity.svg
        resources/icons/link.svg
        resources/icons/plus.svg
        resources/icons/pause.svg
        resources/icons/play.svg
        resources/icons/search.svg
        resources/icons/trash.svg
        resources/icons/video.svg
)

qt_add_qml_module(dyx-qt
    URI DYX
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/AddDownloadDialog.qml
        qml/components/DirectoryPickerDialog.qml
        qml/components/DyxButton.qml
        qml/components/DyxCard.qml
        qml/components/DyxDialog.qml
        qml/components/DyxIconButton.qml
        qml/components/DyxInput.qml
        qml/components/DyxProgressBar.qml
        qml/components/DyxSidebarItem.qml
        qml/components/DownloadArea.qml
        qml/components/DownloadItem.qml
        qml/components/IconGlyph.qml
        qml/components/SettingsArea.qml
        qml/components/Sidebar.qml
        qml/components/TitleBar.qml
        qml/theme/Colors.qml
        qml/theme/Spacing.qml
        qml/theme/Typography.qml
        qml/theme/Tokens.qml
)

install(TARGETS dyx-qt dyx-relay
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
