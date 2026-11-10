// Notifications: the D-Bus notification server, banners that decay into a
// pane, and the pane itself. home/notifications.nix installs this directory
// as the "shell" Quickshell config.
//
// Every notification becomes an entry in pane.json (~/.local/state/notifications),
// so the pane survives logout and reboot. An entry shows as a banner first
// (top right, focused monitor); when its decay bar runs out it moves to the
// pane. Critical ones stay on screen until dismissed. Ghostty, herdr, media
// and screenshot banners decay in 5 s and are dropped instead.
//
// Driven over IPC by the `notif` wrapper: notif toggle|clear|dnd|isDnd|status.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/notifications"
    readonly property int bannerMs: 6000
    readonly property int dropMs: 5000
    readonly property int cap: 500
    // Entries from an earlier session can't answer their action buttons.
    readonly property string session: Date.now().toString()
    property var live: ({}) // key -> Notification, this session only
    property bool paneOpen: false
    readonly property real now: clock.date.getTime()
    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property var items: store.loaded ? data.items : []
    readonly property var paneItems: items.filter(e => !e.drop)
    readonly property var bannerKeys: items
        .filter(e => e.banner && (!data.dnd || e.urgency === NotificationUrgency.Critical))
        .map(e => e.key)

    function find(key) { return items.find(e => e.key === key) ?? null; }
    function setItems(list) {
        const kept = list.slice(0, cap);
        list.slice(cap).forEach(forget);
        data.items = kept;
        Quickshell.execDetached(["pkill", "-RTMIN+8", "waybar"]);
    }
    function patch(key, fields) {
        setItems(items.map(e => e.key === key ? Object.assign({}, e, fields) : e));
    }
    // Drops what an entry left behind: its live notification and saved image.
    function forget(e) {
        const n = live[e.key];
        delete live[e.key];
        if (n && n.tracked) n.dismiss();
        if (e.image.startsWith("file://" + dir + "/img/"))
            Quickshell.execDetached(["rm", "-f", e.image.slice(7)]);
    }
    function dismiss(key) {
        const e = find(key);
        if (!e) return;
        forget(e);
        setItems(items.filter(x => x.key !== key));
    }
    function clear() {
        items.forEach(forget);
        setItems([]);
    }
    // Banner ran out: drop-apps go away, everything else lands in the pane.
    function decay(key) {
        const e = find(key);
        if (!e) return;
        if (e.drop) {
            const n = live[key];
            delete live[key];
            if (n && n.tracked) n.expire(); // lets `notify-send --wait` exit
            setItems(items.filter(x => x.key !== key));
        } else {
            patch(key, { banner: false });
        }
    }
    function activate(key, actionId) {
        const e = find(key);
        if (!e) return;
        const n = e.session === session ? live[key] : null;
        const action = n ? n.actions.find(a => a.identifier === (actionId || "default")) : null;
        if (action) action.invoke();
        else if (!actionId) focusApp(e);
        if (!n || !n.resident) dismiss(key);
    }
    // No live action to run: focus the app's window, or start the app.
    function focusApp(e) {
        const names = [e.entry, e.app].filter(s => s).map(s => s.toLowerCase());
        const w = ToplevelManager.toplevels.values.find(t => names.some(nm =>
            t.appId.toLowerCase() === nm || t.appId.toLowerCase().endsWith("." + nm)));
        if (w) {
            w.activate();
        } else {
            const de = DesktopEntries.byId(e.entry) ?? DesktopEntries.heuristicLookup(e.app);
            if (de) de.execute();
        }
    }

    function snapshot(n) {
        return {
            app: n.appName,
            icon: n.appIcon,
            entry: n.desktopEntry,
            summary: n.summary,
            body: n.body,
            urgency: n.urgency,
            image: n.image,
            actions: n.actions.filter(a => a.identifier !== "default").map(a => ({ id: a.identifier, text: a.text })),
        };
    }

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const drop = ["screenshot", "notify-send", "media"].includes(n.appName)
                || n.desktopEntry === "com.mitchellh.ghostty" || n.transient;
            if (drop && data.dnd) { n.expire(); return; }

            const key = Date.now() + "-" + n.id;
            root.live[key] = n;
            root.setItems([Object.assign(root.snapshot(n), {
                key, drop, session: root.session, time: Date.now(), banner: true,
            })].concat(root.items));

            // Replacements (notify-send -r) update the same object in place.
            const refresh = () => {
                if (root.find(key)) root.patch(key, Object.assign(root.snapshot(n), { time: Date.now(), banner: true }));
            };
            n.summaryChanged.connect(refresh);
            n.bodyChanged.connect(refresh);
            n.imageChanged.connect(refresh);
            // The app withdrew it (e.g. read on another device).
            n.closed.connect(reason => {
                if (reason === NotificationCloseReason.CloseRequested && root.find(key)) {
                    delete root.live[key];
                    root.setItems(root.items.filter(x => x.key !== key));
                }
            });
        }
    }

    FileView {
        id: store
        property bool loaded: false
        blockLoading: true
        path: root.dir + "/pane.json"
        onLoaded: {
            // Anything that was a banner when the last session ended goes to the pane.
            data.items = data.items.filter(e => !e.drop).map(e => Object.assign({}, e, { banner: false }));
            loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) { loaded = true; writeAdapter(); }
        }
        onAdapterUpdated: if (loaded) writeAdapter()

        adapter: JsonAdapter {
            id: data
            property var items: []
            property bool dnd: false
        }
    }

    IpcHandler {
        target: "notifs"
        function toggle(): void { root.paneOpen = !root.paneOpen; }
        function clear(): void { root.clear(); }
        function dnd(): bool {
            data.dnd = !data.dnd;
            Quickshell.execDetached(["pkill", "-RTMIN+8", "waybar"]);
            return data.dnd;
        }
        function isDnd(): bool { return data.dnd; }
        function count(): int { return root.paneItems.length; }
    }

    // Banners: top right of the focused monitor, newest on top.
    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
        visible: root.bannerKeys.length > 0 && !root.paneOpen
        anchors { top: true; right: true }
        margins { top: 8; right: 8 }
        implicitWidth: 380
        implicitHeight: banners.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notif-banners"

        Column {
            id: banners
            width: parent.width
            spacing: 8
            Repeater {
                model: ScriptModel { values: root.bannerKeys }
                Card {
                    required property string modelData
                    width: banners.width
                    shell: root
                    entry: root.find(modelData)
                    decayMs: entry && entry.urgency === NotificationUrgency.Critical ? 0 : entry && entry.drop ? root.dropMs : root.bannerMs
                }
            }
        }
    }

    // Pane: full-height sidebar on the right. j/k move, Enter runs the
    // action (or opens the app), d dismisses, Esc closes.
    PanelWindow {
        id: pane
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
        visible: root.paneOpen
        anchors { top: true; right: true; bottom: true }
        implicitWidth: 420
        color: "#000000"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notif-pane"
        WlrLayershell.keyboardFocus: root.paneOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Grouped by app (apps ordered by their newest notification), newest first.
        readonly property var rows: {
            const groups = [];
            for (const e of root.paneItems) {
                let g = groups.find(g => g.app === e.app);
                if (!g) groups.push(g = { app: e.app, keys: [] });
                g.keys.push(e.key);
            }
            const rows = [];
            for (const g of groups) {
                rows.push({ header: g.app || "unknown", key: "h:" + g.app });
                for (const k of g.keys) rows.push({ header: "", key: k });
            }
            return rows;
        }
        readonly property var keys: rows.filter(r => !r.header).map(r => r.key)
        property string selected: ""
        readonly property int selIndex: Math.max(0, keys.indexOf(selected))
        function move(step) {
            if (keys.length) selected = keys[Math.min(keys.length - 1, Math.max(0, selIndex + step))];
        }
        onVisibleChanged: if (visible && keys) selected = keys[0] ?? ""
        onKeysChanged: if (keys && keys.indexOf(selected) < 0) selected = keys[Math.min(selIndex, keys.length - 1)] ?? ""

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            border.color: "#333333"
            border.width: 1
            focus: true
            Keys.onPressed: ev => {
                if (ev.key === Qt.Key_J) pane.move(1);
                else if (ev.key === Qt.Key_K) pane.move(-1);
                else if (ev.key === Qt.Key_D && pane.selected) root.dismiss(pane.selected);
                else if ((ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) && pane.selected) root.activate(pane.selected, "");
                else if (ev.key === Qt.Key_Escape || ev.key === Qt.Key_Q) root.paneOpen = false;
                else return;
                ev.accepted = true;
            }

            Item {
                id: head
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                height: 28
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.paneItems.length ? root.paneItems.length + " notifications" : "no notifications"
                    color: "#5c5c5c"
                    font { family: "Atkinson Hyperlegible Next"; pixelSize: 13 }
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: root.paneItems.length > 0
                    text: "clear all"
                    color: clearHover.hovered ? "#e6e6e6" : "#5c5c5c"
                    font { family: "Atkinson Hyperlegible Next"; pixelSize: 13 }
                    HoverHandler { id: clearHover }
                    TapHandler { onTapped: root.clear() }
                }
            }

            ListView {
                id: list
                anchors { top: head.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14; topMargin: 6 }
                clip: true
                spacing: 8
                model: ScriptModel { values: pane.rows; objectProp: "key" }
                currentIndex: pane.rows.findIndex(r => r.key === pane.selected)
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Item {
                    id: row
                    required property var modelData
                    width: list.width
                    height: modelData.header ? 26 : card.height
                    Text {
                        visible: !!row.modelData.header
                        anchors.bottom: parent.bottom
                        text: row.modelData.header.toLowerCase()
                        color: "#5c5c5c"
                        font { family: "Atkinson Hyperlegible Next"; pixelSize: 12; letterSpacing: 0.5 }
                    }
                    Card {
                        id: card
                        visible: !row.modelData.header
                        width: parent.width
                        shell: root
                        entry: row.modelData.header ? null : root.find(row.modelData.key)
                        inPane: true
                        selected: pane.selected === row.modelData.key
                    }
                }
            }
        }
    }
}
