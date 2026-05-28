pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string localeOverride: ""
    readonly property string currentLocale: {
        const overrideLocale = localeOverride && localeOverride !== "system" ? localeOverride : (Qt.locale().name || "en");
        return overrideLocale || "en";
    }
    readonly property string _lang: currentLocale.split(/[_-]/)[0]
    readonly property bool useChinese: _lang === "zh"

    readonly property var _rtlLanguages: ["ar", "he", "iw", "fa", "ur", "ps", "sd", "dv", "yi", "ku"]
    readonly property bool isRtl: _rtlLanguages.includes(_lang)

    readonly property url localChineseTranslation: Qt.resolvedUrl("../translations/poexports/zh_CN.json")
    readonly property url systemChineseTranslation: "file:///usr/share/quickshell/dms/translations/poexports/zh_CN.json"

    property var zhTranslations: ({})
    property bool zhTranslationsLoaded: false
    property bool _loadingSystemFallback: false

    FileView {
        id: chineseLoader
        path: root.localChineseTranslation

        onLoaded: {
            try {
                root.zhTranslations = JSON.parse(text());
                root.zhTranslationsLoaded = true;
                root._loadingSystemFallback = false;
                console.info(`I18n: Loaded zh_CN translations (${Object.keys(root.zhTranslations).length} contexts)`);
            } catch (e) {
                console.warn("I18n: Failed to parse local zh_CN translations:", e);
                root._loadSystemFallback();
            }
        }

        onLoadFailed: error => {
            console.warn(`I18n: Failed to load local zh_CN translations (${error})`);
            root._loadSystemFallback();
        }
    }

    function _loadSystemFallback() {
        if (_loadingSystemFallback)
            return;
        _loadingSystemFallback = true;
        chineseLoader.path = systemChineseTranslation;
        chineseLoader.reload();
    }

    Component.onCompleted: {
        chineseLoader.reload();
    }

    function setLocaleOverride(localeTag) {
        localeOverride = localeTag && localeTag !== "system" ? localeTag : "";
    }

    function tr(term, context) {
        if (!useChinese || !zhTranslationsLoaded || !zhTranslations)
            return term;

        const ctx = context || term;
        if (zhTranslations[ctx] && zhTranslations[ctx][term])
            return zhTranslations[ctx][term];

        for (const c in zhTranslations) {
            if (zhTranslations[c] && zhTranslations[c][term])
                return zhTranslations[c][term];
        }

        return term;
    }

    function trContext(context, term) {
        if (!useChinese || !zhTranslationsLoaded || !zhTranslations)
            return term;
        if (zhTranslations[context] && zhTranslations[context][term])
            return zhTranslations[context][term];
        return term;
    }

    function locale() {
        return Qt.locale(useChinese ? "zh_CN" : "en_US");
    }
}
