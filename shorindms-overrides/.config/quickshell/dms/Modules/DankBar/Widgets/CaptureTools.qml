import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property bool recordingActive: NiriService.hasActiveCast || PrivacyService.screensharingActive
    readonly property bool menuVisible: contextMenuWindow.visible
    readonly property string recordingMenuCommand: "shorin-screenrec-menu"
    readonly property real indicatorIconSize: Math.max(14, Theme.barIconSize(root.barThickness, -10, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale))
    readonly property var menuItems: [
        {
            "icon": "crop_free",
            "text": I18n.tr("Area Screenshot"),
            "action": "area"
        },
        {
            "icon": "window",
            "text": I18n.tr("Window Screenshot"),
            "action": "window"
        },
        {
            "icon": "desktop_windows",
            "text": I18n.tr("Screen Screenshot"),
            "action": "screen"
        },
        {
            "icon": "screen_record",
            "text": I18n.tr("Recording Menu"),
            "action": "record"
        }
    ]

    function recordingMenuLocale() {
        const locale = (I18n.currentLocale || "en").replace("-", "_");
        switch (locale) {
        case "zh":
            return "zh_CN.UTF-8";
        case "ja":
            return "ja_JP.UTF-8";
        case "en":
            return "en_US.UTF-8";
        default:
            return locale.includes(".") ? locale : `${locale}.UTF-8`;
        }
    }

    function openContextMenu() {
        const screen = root.parentScreen || Screen;
        const screenX = screen.x || 0;
        const screenY = screen.y || 0;
        const isVertical = root.axis?.isVertical ?? false;
        const edge = root.axis?.edge ?? "top";
        const gap = Math.max(Theme.spacingXS, root.barSpacing ?? Theme.spacingXS);

        const globalPos = root.mapToGlobal(root.width / 2, root.height / 2);
        const relativeX = globalPos.x - screenX;
        const relativeY = globalPos.y - screenY;

        let anchorX = relativeX;
        let anchorY = relativeY;

        if (isVertical) {
            anchorX = edge === "left" ? (root.barThickness + root.barSpacing + gap) : (screen.width - (root.barThickness + root.barSpacing + gap));
            anchorY = relativeY;
        } else {
            anchorX = relativeX;
            anchorY = edge === "bottom" ? (screen.height - (root.barThickness + root.barSpacing + gap)) : (root.barThickness + root.barSpacing + gap);
        }

        contextMenuWindow.showAt(anchorX, anchorY, isVertical, edge, screen);
    }

    function openRecordingMenu() {
        contextMenuWindow.closeMenu();
        Proc.runCommand("capture-tools-record-menu", ["sh", "-lc", `command -v "${recordingMenuCommand}" >/dev/null 2>&1`], (output, exitCode) => {
            if (exitCode === 0) {
                const locale = recordingMenuLocale();
                Quickshell.execDetached(["env", `LANG=${locale}`, `LC_MESSAGES=${locale}`, recordingMenuCommand]);
                return;
            }
            ToastService.showError(I18n.tr("Recording menu command not found"), recordingMenuCommand, "", "capture-tools-record-menu");
        }, 0, 2000);
    }

    function runCaptureAction(action) {
        contextMenuWindow.closeMenu();

        switch (action) {
        case "area":
            if (!NiriService.screenshot())
                ToastService.showError(I18n.tr("Failed to start area screenshot"), "", "", "capture-tools-area");
            break;
        case "window":
            if (!NiriService.screenshotWindow())
                ToastService.showError(I18n.tr("Failed to start window screenshot"), "", "", "capture-tools-window");
            break;
        case "screen":
            if (!NiriService.screenshotScreen())
                ToastService.showError(I18n.tr("Failed to start screen screenshot"), "", "", "capture-tools-screen");
            break;
        case "record":
            openRecordingMenu();
            break;
        }
    }

    onClicked: openContextMenu()
    onRightClicked: function () {
        openRecordingMenu();
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? root.indicatorIconSize : iconRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? iconColumn.implicitHeight : root.indicatorIconSize

            Column {
                id: iconColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Item {
                    width: root.indicatorIconSize
                    height: root.indicatorIconSize

                    DankIcon {
                        anchors.centerIn: parent
                        name: "photo_camera"
                        size: root.indicatorIconSize
                        color: root.menuVisible ? Theme.primary : Theme.widgetIconColor
                    }
                }

                Item {
                    width: root.indicatorIconSize
                    height: root.indicatorIconSize

                    DankIcon {
                        anchors.centerIn: parent
                        name: "screen_record"
                        size: root.indicatorIconSize
                        color: root.recordingActive ? Theme.error : Theme.widgetIconColor
                    }

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.error
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -1
                        anchors.topMargin: -1
                        visible: root.recordingActive
                    }
                }
            }

            Row {
                id: iconRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Item {
                    width: root.indicatorIconSize
                    height: root.indicatorIconSize

                    DankIcon {
                        anchors.centerIn: parent
                        name: "photo_camera"
                        size: root.indicatorIconSize
                        color: root.menuVisible ? Theme.primary : Theme.widgetIconColor
                    }
                }

                Item {
                    width: root.indicatorIconSize
                    height: root.indicatorIconSize

                    DankIcon {
                        anchors.centerIn: parent
                        name: "screen_record"
                        size: root.indicatorIconSize
                        color: root.recordingActive ? Theme.error : Theme.widgetIconColor
                    }

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.error
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -1
                        anchors.topMargin: -1
                        visible: root.recordingActive
                    }
                }
            }
        }
    }

    PanelWindow {
        id: contextMenuWindow

        WindowBlur {
            targetWindow: contextMenuWindow
            blurX: menuContainer.x
            blurY: menuContainer.y
            blurWidth: contextMenuWindow.visible ? menuContainer.width : 0
            blurHeight: contextMenuWindow.visible ? menuContainer.height : 0
            blurRadius: Theme.cornerRadius
        }

        WlrLayershell.namespace: "dms:capture-tools-menu"

        property bool isVertical: false
        property string edge: "top"
        property point anchorPos: Qt.point(0, 0)

        function showAt(x, y, vertical, barEdge, targetScreen) {
            if (targetScreen) {
                contextMenuWindow.screen = targetScreen;
            }

            anchorPos = Qt.point(x, y);
            isVertical = vertical ?? false;
            edge = barEdge ?? "top";

            visible = true;

            if (contextMenuWindow.screen) {
                TrayMenuManager.registerMenu(contextMenuWindow.screen.name, contextMenuWindow);
            }
        }

        function closeMenu() {
            visible = false;

            if (contextMenuWindow.screen) {
                TrayMenuManager.unregisterMenu(contextMenuWindow.screen.name);
            }
        }

        screen: null
        visible: false
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        Component.onDestruction: {
            if (contextMenuWindow.screen) {
                TrayMenuManager.unregisterMenu(contextMenuWindow.screen.name);
            }
        }

        Connections {
            target: PopoutManager
            function onPopoutOpening() {
                contextMenuWindow.closeMenu();
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: contextMenuWindow.closeMenu()
        }

        Rectangle {
            id: menuContainer

            x: {
                if (contextMenuWindow.isVertical) {
                    if (contextMenuWindow.edge === "left") {
                        return Math.min(contextMenuWindow.width - width - 10, contextMenuWindow.anchorPos.x);
                    }
                    return Math.max(10, contextMenuWindow.anchorPos.x - width);
                }
                const left = 10;
                const right = contextMenuWindow.width - width - 10;
                const want = contextMenuWindow.anchorPos.x - width / 2;
                return Math.max(left, Math.min(right, want));
            }
            y: {
                if (contextMenuWindow.isVertical) {
                    const top = 10;
                    const bottom = contextMenuWindow.height - height - 10;
                    const want = contextMenuWindow.anchorPos.y - height / 2;
                    return Math.max(top, Math.min(bottom, want));
                }
                if (contextMenuWindow.edge === "top") {
                    return Math.min(contextMenuWindow.height - height - 10, contextMenuWindow.anchorPos.y);
                }
                return Math.max(10, contextMenuWindow.anchorPos.y - height);
            }

            width: Math.min(260, Math.max(190, menuColumn.implicitWidth + Theme.spacingS * 2))
            height: Math.max(64, menuColumn.implicitHeight + Theme.spacingS * 2)
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.color: BlurService.enabled ? BlurService.borderColor : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: BlurService.enabled ? BlurService.borderWidth : 1

            opacity: contextMenuWindow.visible ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.emphasizedEasing
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.leftMargin: 2
                anchors.rightMargin: -2
                anchors.bottomMargin: -4
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.15)
                z: -1
            }

            Column {
                id: menuColumn
                width: parent.width - Theme.spacingS * 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                spacing: 1

                Repeater {
                    model: root.menuItems

                    Rectangle {
                        required property var modelData

                        width: menuColumn.width
                        height: 30
                        radius: Theme.cornerRadius
                        color: itemArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData.icon
                                size: 16
                                color: modelData.action === "record" && root.recordingActive ? Theme.error : Theme.surfaceText
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }
                        }

                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.runCaptureAction(modelData.action);
                            }
                        }
                    }
                }
            }
        }
    }
}
