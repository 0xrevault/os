import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 800
    height: 540
    visible: true
    title: "WASM Render Sanity"
    color: "#5c86d6"

    Rectangle {
        id: bg
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                id: g1
                position: 0
                color: "#6fa3ef"
            }
            GradientStop {
                id: g2
                position: 1
                color: "#3e6fb0"
            }
        }
    }

    Column {
        id: col
        spacing: 16
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width * 0.9, 660)

        Text {
            id: titleEn
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Hello, WASM"
            color: "white"
            font.pixelSize: 36
            font.bold: true
        }
        Text {
            id: titleZh
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "你好，世界"
            color: "white"
            font.pixelSize: 24
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "white"
            opacity: 0.35
        }

        Row {
            spacing: 12
            anchors.horizontalCenter: parent.horizontalCenter
            Repeater {
                model: ["#FF6B6B", "#FFD93D", "#6BCB77"]
                Rectangle {
                    width: 80
                    height: 40
                    radius: 8
                    color: modelData
                    border.color: Qt.darker(modelData, 1.25)
                    border.width: 2
                }
            }
        }

        Rectangle {
            id: btn
            width: 160
            height: 44
            radius: 12
            color: pressed ? "#1f9d55" : "#22c55e"
            border.color: "#166534"
            border.width: 2
            property bool pressed: false
            Text {
                anchors.centerIn: parent
                text: pressed ? "Clicked!" : "Click me"
                color: "white"
                font.pixelSize: 18
            }
            MouseArea {
                anchors.fill: parent
                onPressed: btn.pressed = true
                onReleased: btn.pressed = false
                onClicked: box.color = box.color === "#fecaca" ? "#a7f3d0" : "#fecaca"
            }
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        Rectangle {
            id: box
            width: parent.width
            height: 80
            radius: 12
            color: "#a7f3d0"
            border.color: "#10b981"
            border.width: 2
            Text {
                anchors.centerIn: parent
                text: "Colored Box"
                color: "#065f46"
                font.pixelSize: 20
            }
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: 8
            color: "white"
            border.color: "#93c5fd"
            border.width: 2
            TextInput {
                id: ti
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                color: "black"
                font.pixelSize: 18
                focus: true
            }
            // 简单的 placeholder
            Text {
                anchors.fill: parent
                anchors.margins: 8
                text: "Type here to test keyboard…"
                color: "#9ca3af"
                visible: !ti.activeFocus && ti.text.length === 0
                verticalAlignment: Text.AlignVCenter
            }
        }

        Image {
            width: 48
            height: 48
            source: "data:image/svg+xml;utf8," + "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'>" + "<circle cx='32' cy='32' r='28' fill='#2563eb'/>" + "<path d='M20 34l8 8 16-16' stroke='white' stroke-width='6' fill='none' stroke-linecap='round' stroke-linejoin='round'/></svg>"
        }

        Canvas {
            width: 140
            height: 60
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "#ef4444";
                ctx.fillRect(0, 0, width, height);
                ctx.beginPath();
                ctx.arc(30, 30, 20, 0, Math.PI * 2);
                ctx.fillStyle = "#22c55e";
                ctx.fill();
                ctx.fillStyle = "#111827";
                ctx.fillRect(70, 15, 50, 30);
            }
        }

        Rectangle {
            width: parent.width
            height: 60
            radius: 8
            color: "white"
            opacity: 0.92
            border.color: "#e5e7eb"
            Row {
                anchors.centerIn: parent
                spacing: 12
                Text {
                    text: "EN w:" + Math.round(titleEn.paintedWidth)
                }
                Text {
                    text: "ZH w:" + Math.round(titleZh.paintedWidth)
                }
                Text {
                    text: "DPR:" + win.screen.devicePixelRatio.toFixed(2)
                }
                Text {
                    text: "Size:" + win.width + "x" + win.height
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: {
            const a = (g1.color === "#6fa3ef");
            g1.color = a ? "#f97316" : "#6fa3ef";
            g2.color = a ? "#be123c" : "#3e6fb0";
        }
    }

    Rectangle {
        id: spinner
        width: 54
        height: 54
        radius: 12
        color: "#fbbf24"
        border.color: "#d97706"
        border.width: 2
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        NumberAnimation on rotation {
            running: true
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1600
        }
        Text {
            anchors.centerIn: parent
            text: "◴"
            font.pixelSize: 22
        }
    }
}
