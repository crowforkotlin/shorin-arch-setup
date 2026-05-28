import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property bool recordingActive: NiriService.hasActiveCast || PrivacyService.screensharingActive
    readonly property string recordingMenuCommand: "shorin-screenrec-menu"
    readonly property real iconSize: Math.max(16, Theme.barIconSize(root.barThickness, -8, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale))

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

    function openRecordingMenu() {
        Proc.runCommand("screen-record-button-menu", ["sh", "-lc", `command -v "${recordingMenuCommand}" >/dev/null 2>&1`], (output, exitCode) => {
            if (exitCode === 0) {
                const locale = recordingMenuLocale();
                Quickshell.execDetached(["env", `LANG=${locale}`, `LC_MESSAGES=${locale}`, recordingMenuCommand]);
                return;
            }
            ToastService.showError(I18n.tr("Recording menu command not found"), recordingMenuCommand, "", "screen-record-button-menu");
        }, 0, 2000);
    }

    onClicked: openRecordingMenu()
    onRightClicked: function () {
        openRecordingMenu();
    }

    content: Component {
        Item {
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize

            DankIcon {
                anchors.centerIn: parent
                name: "screen_record"
                size: root.iconSize
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
