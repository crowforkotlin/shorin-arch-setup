import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property real iconSize: Math.max(16, Theme.barIconSize(root.barThickness, -8, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale))
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
        }
    ]

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

    function runCaptureAction(action) {
        contextMenuWindow.closeMenu();

        switch (action) {
        case "area":
            if (!NiriService.screenshot())
                ToastService.showError(I18n.tr("Failed to start area screenshot"), "", "", "screenshot-tools-area");
            break;
        case "window":
            if (!NiriService.screenshotWindow())
                ToastService.showError(I18n.tr("Failed to start window screenshot"), "", "", "screenshot-tools-window");
            break;
        case "screen":
            if (!NiriService.screenshotScreen())
                ToastService.showError(I18n.tr("Failed to start screen screenshot"), "", "", "screenshot-tools-screen");
            break;
        }
    }

    onClicked: openContextMenu()
    onRightClicked: function () {
        openContextMenu();
    }

    content: Component {
        Item {
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize

            DankIcon {
                anchors.centerIn: parent
                name: "photo_camera"
                size: root.iconSize
                color: contextMenuWindow.visible ? Theme.primary : Theme.widgetIconColor
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

        WlrLayershell.namespace: "dms:screenshot-tools-menu"

        property bool isVertical: false
        property string edge: "top"
        property point anchorPos: Qt.point(0, 0)

        function showAt(x, y, vertical, barEdge, targetScreen) {
            if (targetScreen)
                contextMenuWindow.screen = targetScreen;

            anchorPos = Qt.point(x, y);
            isVertical = vertical ?? false;
            edge = barEdge ?? "top";
            visible = true;

            if (contextMenuWindow.screen)
                TrayMenuManager.registerMenu(contextMenuWindow.screen.name, contextMenuWindow);
        }

        function closeMenu() {
            visible = false;

            if (contextMenuWindow.screen)
                TrayMenuManager.unregisterMenu(contextMenuWindow.screen.name);
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
            if (contextMenuWindow.screen)
                TrayMenuManager.unregisterMenu(contextMenuWindow.screen.name);
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
                    if (contextMenuWindow.edge === "left")
                        return Math.min(contextMenuWindow.width - width - 10, contextMenuWindow.anchorPos.x);
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
                if (contextMenuWindow.edge === "top")
                    return Math.min(contextMenuWindow.height - height - 10, contextMenuWindow.anchorPos.y);
                return Math.max(10, contextMenuWindow.anchorPos.y - height);
            }

            width: Math.min(250, Math.max(190, menuColumn.implicitWidth + Theme.spacingS * 2))
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
                                color: Theme.surfaceText
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
                            onClicked: root.runCaptureAction(modelData.action)
                        }
                    }
                }
            }
        }
    }
}
