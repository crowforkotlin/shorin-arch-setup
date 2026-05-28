import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Widgets

StyledRect {
    id: listDelegateRoot

    required property bool fileIsDir
    required property string filePath
    required property string fileName
    required property int index
    required property var fileModified
    required property int fileSize

    property int selectedIndex: -1
    property bool keyboardNavigationActive: false

    signal itemClicked(int index, string path, string name, bool isDir)
    signal itemSelected(int index, string path, string name, bool isDir)

    function getFileExtension(fileName) {
        const parts = fileName.split('.');
        if (parts.length > 1) {
            return parts[parts.length - 1].toLowerCase();
        }
        return "";
    }

    function determineFileType(fileName) {
        const ext = getFileExtension(fileName);

        const imageExts = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "svg", "ico", "jxl", "avif", "heif", "exr"];
        if (imageExts.includes(ext)) {
            return "image";
        }

        const videoExts = ["mp4", "mkv", "avi", "mov", "webm", "flv", "wmv", "m4v"];
        if (videoExts.includes(ext)) {
            return "video";
        }

        const audioExts = ["mp3", "wav", "flac", "ogg", "m4a", "aac", "wma"];
        if (audioExts.includes(ext)) {
            return "audio";
        }

        const codeExts = ["js", "ts", "jsx", "tsx", "py", "go", "rs", "c", "cpp", "h", "java", "kt", "swift", "rb", "php", "html", "css", "scss", "json", "xml", "yaml", "yml", "toml", "sh", "bash", "zsh", "fish", "qml", "vue", "svelte"];
        if (codeExts.includes(ext)) {
            return "code";
        }

        const docExts = ["txt", "md", "pdf", "doc", "docx", "odt", "rtf"];
        if (docExts.includes(ext)) {
            return "document";
        }

        const archiveExts = ["zip", "tar", "gz", "bz2", "xz", "7z", "rar"];
        if (archiveExts.includes(ext)) {
            return "archive";
        }

        if (!ext || fileName.indexOf('.') === -1) {
            return "binary";
        }

        return "file";
    }

    function isImageFile(fileName) {
        if (!fileName) {
            return false;
        }
        return determineFileType(fileName) === "image";
    }

    function isVideoFile(fileName) {
        if (!fileName) {
            return false;
        }
        return determineFileType(fileName) === "video";
    }

    property bool isImage: isImageFile(listDelegateRoot.fileName)
    property bool isVideo: isVideoFile(listDelegateRoot.fileName)

    property string _xdgCacheHome: Paths.strip(Paths.xdgCache)
    property string videoThumbnailPath: {
        if (!listDelegateRoot.fileIsDir && isVideo) {
            const hash = Qt.md5("file://" + listDelegateRoot.filePath);
            return _xdgCacheHome + "/thumbnails/normal/" + hash + ".png";
        }
        return "";
    }
    property string _videoThumb: ""
    property bool _videoThumbPending: false
    property bool previewCapable: !listDelegateRoot.fileIsDir && (isImage || isVideo)
    property bool previewReady: previewCapable && listPreviewImage.status === Image.Ready
    property bool previewLoading: {
        if (!previewCapable)
            return false;
        if (isVideo)
            return _videoThumbPending;
        if (listPreviewImage.imagePath === "")
            return false;
        return listPreviewImage.status === Image.Loading || listPreviewImage.status === Image.Null;
    }

    onVideoThumbnailPathChanged: {
        _videoThumb = "";
        _videoThumbPending = false;
        if (!videoThumbnailPath)
            return;
        const thumbPath = videoThumbnailPath;
        const fp = listDelegateRoot.filePath;
        Paths.mkdir(_xdgCacheHome + "/thumbnails/normal");
        _videoThumbPending = true;
        Proc.runCommand(null, ["test", "-f", thumbPath], function (output, exitCode) {
            if (exitCode === 0) {
                _videoThumb = thumbPath;
                _videoThumbPending = false;
            } else {
                Proc.runCommand(null, ["ffmpegthumbnailer", "-i", fp, "-o", thumbPath, "-s", "128", "-f"], function (output, exitCode) {
                    if (exitCode === 0)
                        _videoThumb = thumbPath;
                    _videoThumbPending = false;
                });
            }
        });
    }

    function getIconForFile(fileName) {
        const lowerName = fileName.toLowerCase();
        if (lowerName.startsWith("dockerfile")) {
            return "docker";
        }
        const ext = fileName.split('.').pop();
        return ext || "";
    }

    function formatFileSize(size) {
        if (size < 1024)
            return size + " B";
        if (size < 1024 * 1024)
            return (size / 1024).toFixed(1) + " KB";
        if (size < 1024 * 1024 * 1024)
            return (size / (1024 * 1024)).toFixed(1) + " MB";
        return (size / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    height: 44
    radius: Theme.cornerRadius
    color: {
        if (keyboardNavigationActive && listDelegateRoot.index === selectedIndex)
            return Theme.surfacePressed;
        return listMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent";
    }
    border.color: keyboardNavigationActive && listDelegateRoot.index === selectedIndex ? Theme.primary : "transparent"
    border.width: (keyboardNavigationActive && listDelegateRoot.index === selectedIndex) ? 2 : 0

    Component.onCompleted: {
        if (keyboardNavigationActive && listDelegateRoot.index === selectedIndex)
            itemSelected(listDelegateRoot.index, listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir);
    }

    onSelectedIndexChanged: {
        if (keyboardNavigationActive && selectedIndex === listDelegateRoot.index)
            itemSelected(listDelegateRoot.index, listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir);
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingS

        Item {
            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: listPreviewImage
                anchors.fill: parent
                property string imagePath: {
                    if (!listDelegateRoot.fileIsDir && isImage)
                        return listDelegateRoot.filePath;
                    if (_videoThumb)
                        return _videoThumb;
                    return "";
                }
                source: imagePath ? "file://" + imagePath.split('/').map(s => encodeURIComponent(s)).join('/') : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 32
                sourceSize.height: 32
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: listPreviewImage
                maskEnabled: true
                maskSource: listImageMask
                visible: previewCapable
                opacity: previewReady ? 1 : 0
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Item {
                id: listImageMask
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: "black"
                    antialiasing: true
                }
            }

            DankNFIcon {
                anchors.centerIn: parent
                name: listDelegateRoot.fileIsDir ? "folder" : getIconForFile(listDelegateRoot.fileName)
                size: Theme.iconSize - 2
                color: listDelegateRoot.fileIsDir ? Theme.primary : Theme.surfaceText
                visible: !previewCapable || opacity > 0.01
                opacity: previewCapable && previewReady ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
            }

            BusyIndicator {
                anchors.centerIn: parent
                width: 16
                height: 16
                running: previewLoading
                visible: running
                opacity: running ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        StyledText {
            text: listDelegateRoot.fileName || ""
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            width: parent.width - 280
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            maximumLineCount: 1
            clip: true
        }

        StyledText {
            text: listDelegateRoot.fileIsDir ? "" : formatFileSize(listDelegateRoot.fileSize)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            width: 70
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: Qt.formatDateTime(listDelegateRoot.fileModified, "MMM d, yyyy h:mm AP")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            width: 140
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: listMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            itemClicked(listDelegateRoot.index, listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir);
        }
    }
}
