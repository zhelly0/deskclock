import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    property alias cfg_use24h: use24h.checked
    property alias cfg_showSeconds: showSeconds.checked
    property alias cfg_showDate: showDate.checked
    property alias cfg_showWeather: showWeather.checked
    // Set together when a search result is picked.
    property string cfg_city
    property string cfg_cityDetail
    property real cfg_latitude
    property real cfg_longitude
    property alias cfg_fahrenheit: fahrenheit.checked
    property alias cfg_showCity: showCity.checked
    property alias cfg_showDesktops: showDesktops.checked
    property alias cfg_showDesktopNames: showDesktopNames.checked
    property alias cfg_showStickyApps: showStickyApps.checked
    property alias cfg_maxIcons: maxIcons.value
    property alias cfg_iconSize: iconSize.value
    property alias cfg_showNowPlaying: showNowPlaying.checked
    property alias cfg_hideWhenPaused: hideWhenPaused.checked
    property alias cfg_showAlbumArt: showAlbumArt.checked
    property alias cfg_showProgress: showProgress.checked
    property alias cfg_scale: scaleCtl.value
    property alias cfg_useThemeColor: useThemeColor.checked
    property alias cfg_textColor: textColor.color
    property alias cfg_shadow: shadow.checked
    property alias cfg_cardOpacity: cardOpacity.value
    property alias cfg_autoCenter: autoCenter.checked
    property alias cfg_autoCenterVertical: autoCenterVertical.checked

    component SliderRow: RowLayout {
        property alias from: slider.from
        property alias to: slider.to
        property alias stepSize: slider.stepSize
        property alias value: slider.value
        property string suffix: ""
        QQC2.Slider {
            id: slider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            snapMode: QQC2.Slider.SnapAlways
        }
        QQC2.Label {
            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            text: slider.value + parent.suffix
        }
    }

    function pick(i) {
        const r = results.get(i);
        cfg_city = r.name;
        cfg_cityDetail = r.detail;
        cfg_latitude = r.lat;
        cfg_longitude = r.lon;
        resultsPopup.close();
        search.text = "";
        searchStatus.text = "";
    }

    Timer {
        id: searchDelay
        interval: 400
        onTriggered: {
            const q = search.text.trim();
            if (q.length < 2) {
                results.clear();
                resultsPopup.close();
                searchStatus.text = "";
                return;
            }
            searchStatus.text = i18n("Searching…");
            const lang = Qt.locale().name.split("_")[0] || "en";
            geocoder.connectSource("python3 '" + Qt.resolvedUrl("../code/geocode.py").toString().replace(/^file:\/\//, "")
                                   + "' '" + q.replace(/'/g, "'\\''") + "' " + lang);
        }
    }

    P5Support.DataSource {
        id: geocoder
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            let list = [];
            try {
                list = JSON.parse(data.stdout);
            } catch (e) {
                searchStatus.text = i18n("Search failed. Are you online?");
                return;
            }
            results.clear();
            for (const r of list) {
                results.append({ name: r.name, detail: [r.region, r.country].filter(x => x).join(", "), lat: r.lat, lon: r.lon });
            }
            searchStatus.text = list.length ? "" : i18n("No places found");
            if (list.length) resultsPopup.open(); else resultsPopup.close();
        }
    }

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Clock") }
        QQC2.CheckBox { id: use24h; Kirigami.FormData.label: i18n("Show:"); text: i18n("24-hour time") }
        QQC2.CheckBox { id: showSeconds; text: i18n("Seconds") }
        QQC2.CheckBox { id: showDate; text: i18n("Date") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Weather") }
        QQC2.CheckBox { id: showWeather; Kirigami.FormData.label: i18n("Show:"); text: i18n("Outdoor temperature") }
        ColumnLayout {
            Kirigami.FormData.label: i18n("Location:")
            enabled: showWeather.checked
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: cfg_city + (cfg_cityDetail ? " · " + cfg_cityDetail : "")
                font.weight: Font.DemiBold
            }
            Kirigami.SearchField {
                id: search
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                placeholderText: i18n("Search for a city or town…")
                // Search shortly after typing stops rather than on every keystroke.
                onTextEdited: searchDelay.restart()
                onAccepted: searchDelay.triggered()
                Keys.onDownPressed: if (results.count) { resultsPopup.open(); resultList.forceActiveFocus(); }

                QQC2.Popup {
                    id: resultsPopup
                    y: search.height + Kirigami.Units.smallSpacing
                    width: search.width
                    padding: 1
                    contentItem: ListView {
                        id: resultList
                        implicitHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 16)
                        clip: true
                        model: ListModel { id: results }
                        keyNavigationEnabled: true
                        delegate: QQC2.ItemDelegate {
                            required property int index
                            required property string name
                            required property string detail
                            required property real lat
                            required property real lon
                            width: ListView.view.width
                            highlighted: ListView.isCurrentItem
                            contentItem: ColumnLayout {
                                spacing: 0
                                QQC2.Label { text: name; font.weight: Font.DemiBold }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: detail + "  ·  " + lat.toFixed(2) + ", " + lon.toFixed(2)
                                    opacity: 0.7
                                    font: Kirigami.Theme.smallFont
                                    elide: Text.ElideRight
                                }
                            }
                            onClicked: pick(index)
                            Keys.onReturnPressed: pick(index)
                        }
                    }
                }
            }
            QQC2.Label {
                id: searchStatus
                visible: text !== ""
                opacity: 0.7
                font: Kirigami.Theme.smallFont
            }
        }
        QQC2.CheckBox { id: showCity; text: i18n("Show city name"); enabled: showWeather.checked }
        QQC2.CheckBox { id: fahrenheit; text: i18n("Fahrenheit"); enabled: showWeather.checked }
        QQC2.Label {
            text: i18n("Weather data from Open-Meteo.com (no account needed).")
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Virtual desktops") }
        QQC2.CheckBox { id: showDesktops; Kirigami.FormData.label: i18n("Show:"); text: i18n("Desktop overview") }
        QQC2.CheckBox { id: showDesktopNames; text: i18n("Desktop names (off = numbers)"); enabled: showDesktops.checked }
        QQC2.CheckBox { id: showStickyApps; text: i18n("Apps pinned to all desktops"); enabled: showDesktops.checked }
        SliderRow { id: maxIcons; Kirigami.FormData.label: i18n("Max icons per desktop:"); from: 1; to: 12; stepSize: 1; enabled: showDesktops.checked }
        SliderRow { id: iconSize; Kirigami.FormData.label: i18n("Icon size:"); from: 16; to: 48; stepSize: 2; suffix: " px"; enabled: showDesktops.checked }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Now playing") }
        QQC2.CheckBox { id: showNowPlaying; Kirigami.FormData.label: i18n("Show:"); text: i18n("Current media (Spotify, browsers, …)") }
        QQC2.CheckBox { id: showAlbumArt; text: i18n("Album art"); enabled: showNowPlaying.checked }
        QQC2.CheckBox { id: showProgress; text: i18n("Progress bar"); enabled: showNowPlaying.checked }
        QQC2.CheckBox { id: hideWhenPaused; text: i18n("Hide when paused or stopped"); enabled: showNowPlaying.checked }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Appearance") }
        SliderRow { id: scaleCtl; Kirigami.FormData.label: i18n("Size:"); from: 50; to: 200; stepSize: 5; suffix: " %" }
        QQC2.CheckBox { id: useThemeColor; Kirigami.FormData.label: i18n("Text color:"); text: i18n("Follow the color scheme") }
        KQuickControls.ColorButton { id: textColor; enabled: !useThemeColor.checked }
        QQC2.CheckBox { id: shadow; text: i18n("Drop shadow for readability") }
        SliderRow { id: cardOpacity; Kirigami.FormData.label: i18n("Desktop card tint:"); from: 0; to: 30; stepSize: 1; suffix: " %" }
        QQC2.CheckBox { id: autoCenter; Kirigami.FormData.label: i18n("Position:"); text: i18n("Center horizontally on the screen") }
        QQC2.CheckBox { id: autoCenterVertical; text: i18n("Center vertically on the screen") }
        QQC2.Label {
            text: i18n("Uncheck to place the widget freely in Edit Mode.")
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }
    }
}
