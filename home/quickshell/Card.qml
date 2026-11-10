// One notification, as a banner or a pane row. Left click runs the default
// action (or focuses the app), right click dismisses. Banners decay: a thin
// bar along the bottom shrinks over decayMs (paused while hovered), then the
// shell moves the entry to the pane or drops it. decayMs 0 = stays put.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card

    required property var shell
    property var entry: null
    property int decayMs: 0
    property bool inPane: false
    property bool selected: false

    readonly property var e: entry ?? ({ key: "", app: "", icon: "", summary: "", body: "", image: "", actions: [], time: 0, urgency: 1, session: "" })
    readonly property bool isLive: e.session === shell.session
    readonly property bool critical: e.urgency === NotificationUrgency.Critical
    readonly property string picture: {
        const src = e.image || e.icon || "";
        if (src.startsWith("/")) return "file://" + src;
        if (src.includes("://")) return src;
        return src ? Quickshell.iconPath(src, true) : "";
    }

    height: body.implicitHeight + 20
    color: selected ? "#1c1c1c" : "#000000"
    border.color: critical ? "#ff8080" : selected ? "#5c5c5c" : "#333333"
    border.width: 1

    property real progress: 1
    NumberAnimation {
        id: decay
        target: card
        property: "progress"
        from: 1
        to: 0
        duration: Math.max(1, card.decayMs)
        paused: running && area.containsMouse
        onFinished: {
            const key = card.e.key;
            Qt.callLater(() => card.shell.decay(key));
        }
    }
    // Restart the bar when the notification is replaced (notify-send -r).
    readonly property real stamp: e.time
    onStampChanged: if (decayMs > 0 && !inPane) decay.restart()
    Component.onCompleted: if (decayMs > 0 && !inPane) decay.start()

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: ev => {
            if (ev.button === Qt.RightButton) card.shell.dismiss(card.e.key);
            else card.shell.activate(card.e.key, "");
        }
    }

    Row {
        id: body
        x: 14
        y: 10
        width: parent.width - 28
        spacing: 12

        Image {
            id: pic
            visible: card.picture !== "" && status !== Image.Error
            width: visible ? 40 : 0
            height: 40
            sourceSize { width: 96; height: 96 }
            fillMode: Image.PreserveAspectFit
            source: card.picture
            asynchronous: true
            // Pictures sent inline or as temp files won't exist after a
            // restart, so keep a copy next to pane.json.
            // ponytail: only grabbed while on screen; one that arrives during
            // DND and is never opened in the pane this session is lost.
            onStatusChanged: {
                const img = card.e.image;
                if (status !== Image.Ready || !card.isLive || !Window.window?.visible || !(img.startsWith("image://") || img.startsWith("file:///tmp/") || img.startsWith("/tmp/")))
                    return;
                const key = card.e.key;
                const file = card.shell.dir + "/img/" + key + ".png";
                grabToImage(r => { if (r.saveToFile(file)) card.shell.patch(key, { image: "file://" + file }); });
            }
        }

        Column {
            width: body.width - (pic.visible ? pic.width + body.spacing : 0)
            spacing: 3

            Item {
                width: parent.width
                height: appName.implicitHeight
                Text {
                    id: appName
                    text: (card.e.app || "").toLowerCase()
                    color: "#5c5c5c"
                    font { family: "Atkinson Hyperlegible Next"; pixelSize: 12 }
                }
                Text {
                    anchors.right: parent.right
                    text: card.ago(card.shell.now, card.e.time)
                    color: "#5c5c5c"
                    font { family: "Atkinson Hyperlegible Next"; pixelSize: 12; features: ({ "tnum": 1 }) }
                }
            }
            Text {
                width: parent.width
                text: card.e.summary
                color: "#ffffff"
                elide: Text.ElideRight
                font { family: "Atkinson Hyperlegible Next"; pixelSize: 15; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: (card.e.body || "").replace(/\n/g, "<br>")
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.inPane ? 12 : 5
                elide: Text.ElideRight
                color: "#e6e6e6"
                linkColor: "#e6e6e6"
                font { family: "Atkinson Hyperlegible Next"; pixelSize: 14 }
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Flow {
                width: parent.width
                visible: card.isLive && card.e.actions.length > 0
                spacing: 6
                topPadding: 4
                Repeater {
                    model: card.isLive ? card.e.actions : []
                    Rectangle {
                        required property var modelData
                        width: label.implicitWidth + 16
                        height: label.implicitHeight + 8
                        color: btn.containsMouse ? "#1c1c1c" : "#000000"
                        border.color: "#333333"
                        border.width: 1
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.text
                            color: "#e6e6e6"
                            font { family: "Atkinson Hyperlegible Next"; pixelSize: 13 }
                        }
                        MouseArea {
                            id: btn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: card.shell.activate(card.e.key, modelData.id)
                        }
                    }
                }
            }
        }
    }

    // Decay bar.
    Rectangle {
        visible: card.decayMs > 0 && !card.inPane
        anchors { left: parent.left; bottom: parent.bottom; margins: 1 }
        height: 2
        width: (parent.width - 2) * card.progress
        color: "#5c5c5c"
    }

    function ago(now, t) {
        const m = Math.floor((now - t) / 60000);
        if (m < 1) return "now";
        if (m < 60) return m + "m";
        if (m < 1440) return Math.floor(m / 60) + "h";
        return Qt.formatDate(new Date(t), "ddd d MMM").toLowerCase();
    }
}
