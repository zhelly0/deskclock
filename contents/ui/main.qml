import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property real s: cfg.scale / 100
    readonly property color fg: cfg.useThemeColor ? Kirigami.Theme.textColor : cfg.textColor
    readonly property color fgDim: Qt.rgba(fg.r, fg.g, fg.b, 0.7)
    readonly property string codeDir: Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, "")

    property date now: new Date()
    property var weather: null

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    function px(n) { return Math.round(n * s); }

    // WMO weather code -> freedesktop weather icon name.
    function weatherIcon(code, day) {
        const n = day ? "" : "-night";
        if (code === 0) return "weather-clear" + n;
        if (code === 1) return "weather-few-clouds" + n;
        if (code === 2) return "weather-clouds" + n;
        if (code === 3) return "weather-overcast";
        if (code === 45 || code === 48) return "weather-fog";
        if (code >= 51 && code <= 57) return "weather-showers-scattered";
        if (code >= 61 && code <= 67) return "weather-showers";
        if (code >= 71 && code <= 77) return "weather-snow";
        if (code >= 80 && code <= 82) return "weather-showers";
        if (code === 85 || code === 86) return "weather-snow-scattered";
        if (code >= 95) return "weather-storm";
        return "weather-none-available";
    }

    // WMO weather code -> short description.
    function weatherText(code) {
        if (code === 0) return i18n("Clear sky");
        if (code === 1) return i18n("Mainly clear");
        if (code === 2) return i18n("Partly cloudy");
        if (code === 3) return i18n("Overcast");
        if (code === 45 || code === 48) return i18n("Fog");
        if (code >= 51 && code <= 57) return i18n("Drizzle");
        if (code >= 61 && code <= 67) return i18n("Rain");
        if (code >= 71 && code <= 77) return i18n("Snow");
        if (code >= 80 && code <= 82) return i18n("Rain showers");
        if (code === 85 || code === 86) return i18n("Snow showers");
        if (code >= 95) return i18n("Thunderstorm");
        return i18n("Unknown");
    }

    function compass(deg) {
        return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(deg / 45) % 8];
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    function dayOfYear(d) {
        return Math.round((Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) - Date.UTC(d.getFullYear(), 0, 1)) / 86400000) + 1;
    }

    function utcOffset(d) {
        const m = -d.getTimezoneOffset(), a = Math.abs(m);
        return "UTC" + (m >= 0 ? "+" : "−") + String(Math.floor(a / 60)).padStart(2, "0") + ":" + String(a % 60).padStart(2, "0");
    }

    function capitalize(str) { return str.charAt(0).toUpperCase() + str.slice(1); }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source.indexOf("weather.py") < 0) return;
            try {
                root.weather = JSON.parse(data.stdout);
            } catch (e) {
                // keep the last good reading
            }
        }
    }

    function shellQuote(str) { return "'" + String(str).replace(/'/g, "'\\''") + "'"; }

    function refreshWeather() {
        if (!cfg.showWeather) return;
        exec.connectSource("python3 " + shellQuote(codeDir + "weather.py") + " " + Number(cfg.latitude)
                           + " " + Number(cfg.longitude) + " " + (cfg.fahrenheit ? "fahrenheit" : "celsius"));
    }

    // The script caches for 10 minutes, so polling every 5 is cheap.
    Timer {
        interval: 5 * 60 * 1000
        running: root.cfg.showWeather
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }
    Connections {
        target: root.cfg
        function onLatitudeChanged() { root.refreshWeather(); }
        function onLongitudeChanged() { root.refreshWeather(); }
        function onFahrenheitChanged() { root.refreshWeather(); }
    }

    function switchDesktop(index) {
        exec.connectSource("dbus-send --session --type=method_call --dest=org.kde.KWin /KWin "
                           + "org.kde.KWin.setCurrentDesktop int32:" + (index + 1));
    }

    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }

    fullRepresentation: Item {
        id: full

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        // ---- size + centering ---------------------------------------
        // Plasma only ever grows a desktop widget's container, and its 16 px
        // grid makes exact centering by hand impossible, so do both here.
        readonly property Item container: {
            let c = full.parent;
            while (c && c.layout === undefined) c = c.parent;
            return c;
        }
        readonly property bool editing: (Plasmoid.containment && Plasmoid.containment.corona
                                         && Plasmoid.containment.corona.editMode)
                                        || (container !== null && container.editMode === true)

        function fit() {
            const c = container;
            if (editing || !c || !c.layout) return;
            let changed = false;
            const dw = implicitWidth - width, dh = implicitHeight - height;
            if (Math.abs(dw) >= 1 || Math.abs(dh) >= 1) {
                c.width += dw;
                c.height += dh;
                changed = true;
            }
            if (root.cfg.autoCenter) {
                const x = Math.round((c.layout.width - c.width) / 2);
                if (Math.abs(x - c.x) >= 1) {
                    c.x = x;
                    changed = true;
                }
            }
            // The layout covers the screen minus panels, so this centers in the free area.
            if (root.cfg.autoCenterVertical) {
                const y = Math.round((c.layout.height - c.height) / 2);
                if (Math.abs(y - c.y) >= 1) {
                    c.y = y;
                    changed = true;
                }
            }
            if (changed) c.layout.save();
        }
        onImplicitWidthChanged: Qt.callLater(fit)
        onImplicitHeightChanged: Qt.callLater(fit)
        onEditingChanged: if (!editing) Qt.callLater(fit)
        Component.onCompleted: Qt.callLater(fit)
        Connections {
            target: root.cfg
            function onAutoCenterChanged() { Qt.callLater(full.fit); }
            function onAutoCenterVerticalChanged() { Qt.callLater(full.fit); }
        }

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            spacing: root.px(6)

            // A soft shadow keeps text readable on any wallpaper.
            layer.enabled: root.cfg.shadow
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowBlur: 0.6
                shadowVerticalOffset: 1
                shadowHorizontalOffset: 0
            }

            // ---- clock -------------------------------------------------
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(root.now, root.cfg.use24h
                                    ? (root.cfg.showSeconds ? "HH:mm:ss" : "HH:mm")
                                    : (root.cfg.showSeconds ? "h:mm:ss AP" : "h:mm AP"))
                color: root.fg
                font.pixelSize: root.px(96)
                font.weight: Font.Light
                font.features: { "tnum": 1 }

                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    textFormat: Text.PlainText
                    mainText: root.capitalize(root.now.toLocaleDateString(Qt.locale(), "dddd d MMMM yyyy"))
                    subText: {
                        const d = root.now, w = root.weather;
                        const lines = [
                            i18n("Week %1 · day %2", root.isoWeek(d), root.dayOfYear(d)),
                            root.utcOffset(d)
                        ];
                        if (w && w.sunrise) lines.push(i18n("Sunrise %1 · sunset %2", w.sunrise, w.sunset));
                        return lines.join("\n");
                    }
                }
            }

            // ---- date · weather ---------------------------------------
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.px(10)
                visible: root.cfg.showDate || (root.cfg.showWeather && root.weather)

                Text {
                    visible: root.cfg.showDate
                    // Capitalise only the first letter ("Lördag 3 oktober", "Saturday 3 October").
                    text: {
                        const d = root.now.toLocaleDateString(Qt.locale(), "dddd d MMMM");
                        return d.charAt(0).toUpperCase() + d.slice(1);
                    }
                    color: root.fgDim
                    font.pixelSize: root.px(18)
                }
                Rectangle {
                    visible: root.cfg.showDate && root.cfg.showWeather && root.weather !== null
                    width: root.px(4); height: width; radius: width / 2
                    color: root.fgDim
                }
                Item {
                    visible: root.cfg.showWeather && root.weather !== null
                    implicitWidth: weatherRow.implicitWidth
                    implicitHeight: weatherRow.implicitHeight

                    RowLayout {
                        id: weatherRow
                        anchors.fill: parent
                        spacing: root.px(10)
                        Kirigami.Icon {
                            source: root.weather ? root.weatherIcon(root.weather.code, root.weather.day) : ""
                            implicitWidth: root.px(24)
                            implicitHeight: root.px(24)
                        }
                        Text {
                            text: root.weather
                                  ? Math.round(root.weather.temp) + "°" + (root.cfg.showCity ? "  " + root.cfg.city : "")
                                  : ""
                            color: root.fg
                            font.pixelSize: root.px(18)
                            font.features: { "tnum": 1 }
                        }
                    }

                    PlasmaCore.ToolTipArea {
                        anchors.fill: parent
                        textFormat: Text.PlainText
                        icon: root.weather ? root.weatherIcon(root.weather.code, root.weather.day) : ""
                        mainText: root.weather ? root.weatherText(root.weather.code) + " · " + root.cfg.city : ""
                        subText: {
                            const w = root.weather;
                            if (!w || w.feels === undefined) return "";
                            return [
                                i18n("Feels like %1°", Math.round(w.feels)),
                                i18n("High %1° · low %2°", Math.round(w.high), Math.round(w.low)),
                                i18n("Humidity %1%", w.humidity),
                                i18n("Wind %1 %2 %3", w.wind.toFixed(1), w.windUnit, root.compass(w.windDir)),
                                i18n("Chance of rain today %1%", w.rainChance),
                                i18n("Sunrise %1 · sunset %2", w.sunrise, w.sunset)
                            ].join("\n");
                        }
                    }
                }
            }

            // ---- virtual desktops ------------------------------------
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: root.px(14)
                visible: root.cfg.showDesktops
                spacing: root.px(10)

                Repeater {
                    model: desktops.desktopIds

                    Rectangle {
                        id: card
                        readonly property bool current: modelData === desktops.currentDesktop
                        readonly property int extra: Math.max(0, tasks.count - root.cfg.maxIcons)

                        width: Math.max(root.px(110), cardBody.implicitWidth + root.px(24))
                        height: cardBody.implicitHeight + root.px(18)
                        radius: root.px(12)
                        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b,
                                       (root.cfg.cardOpacity + (hover.containsMouse ? 6 : 0) + (current ? 6 : 0)) / 100)
                        border.width: current ? 2 : 1
                        border.color: current ? Kirigami.Theme.highlightColor
                                              : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)

                        TaskManager.TasksModel {
                            id: tasks
                            groupMode: TaskManager.TasksModel.GroupApplications
                            filterByVirtualDesktop: true
                            virtualDesktop: modelData
                            filterByActivity: true
                            activity: activities.currentActivity
                            filterByScreen: false
                            filterMinimized: false
                        }

                        // Ungrouped twin of `tasks`, for listing individual windows.
                        TaskManager.TasksModel {
                            id: windows
                            groupMode: TaskManager.TasksModel.GroupDisabled
                            filterByVirtualDesktop: true
                            virtualDesktop: modelData
                            filterByActivity: true
                            activity: activities.currentActivity
                            filterByScreen: false
                            filterMinimized: false
                        }

                        function windowList() {
                            const lines = [];
                            for (let i = 0; i < windows.count; i++) {
                                const idx = windows.makeModelIndex(i);
                                if (!root.cfg.showStickyApps && windows.data(idx, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops))
                                    continue;
                                let title = String(windows.data(idx, Qt.DisplayRole) || "");
                                if (title.length > 70) title = title.slice(0, 69) + "…";
                                if (windows.data(idx, TaskManager.AbstractTasksModel.IsMinimized)) title += "  " + i18n("(minimized)");
                                lines.push("• " + title);
                            }
                            if (lines.length > 15) lines.splice(15, lines.length - 15, i18n("…and %1 more", lines.length - 15));
                            return lines.length ? lines.join("\n") : i18n("No open windows");
                        }

                        Column {
                            id: cardBody
                            anchors.centerIn: parent
                            spacing: root.px(6)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.cfg.showDesktopNames ? (desktops.desktopNames[index] || (index + 1)) : (index + 1)
                                color: card.current ? root.fg : root.fgDim
                                font.pixelSize: root.px(12)
                                font.weight: card.current ? Font.DemiBold : Font.Normal
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: root.px(4)
                                height: root.px(root.cfg.iconSize)

                                Repeater {
                                    model: tasks
                                    Kirigami.Icon {
                                        visible: index < root.cfg.maxIcons
                                                 && !model.IsLauncher && !model.IsStartup
                                                 && (root.cfg.showStickyApps || !model.IsOnAllVirtualDesktops)
                                        source: model.decoration
                                        width: root.px(root.cfg.iconSize)
                                        height: width
                                    }
                                }
                                Text {
                                    visible: card.extra > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "+" + card.extra
                                    color: root.fgDim
                                    font.pixelSize: root.px(12)
                                }
                                Text {
                                    visible: tasks.count === 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "—"
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.35)
                                    font.pixelSize: root.px(12)
                                }
                            }
                        }

                        PlasmaCore.ToolTipArea {
                            id: cardTip
                            anchors.fill: parent
                            textFormat: Text.PlainText
                            mainText: (desktops.desktopNames[index] || i18n("Desktop %1", index + 1))
                                      + (card.current ? "  " + i18n("(current)") : "")
                            // Rebuilt on hover so titles are fresh.
                            onContainsMouseChanged: if (containsMouse) subText = card.windowList()

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchDesktop(index)
                            }
                        }
                    }
                }
            }
        }
    }
}
