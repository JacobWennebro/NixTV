// NixTV's login splash: the NixTV logo on navy, pulsing while Plasma starts.
// KSplash shows this until the home screen is ready, raising `stage` (1-6) as
// startup progresses.
import QtQuick

Rectangle {
    id: root
    anchors.fill: parent
    color: "#14142B" // the wordmark colour of the light logo
    property int stage

    // Fades in once; the logo inside pulses until the splash closes.
    Item {
        id: fade
        anchors.fill: parent
        opacity: 0

        Image {
            id: logo
            anchors.centerIn: parent
            source: "images/nixtv-logo.png"
            width: Math.min(parent.width * 0.26, sourceSize.width)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true

            SequentialAnimation {
                running: true
                loops: Animation.Infinite
                ParallelAnimation {
                    ScaleAnimator { target: logo; from: 1.0; to: 1.06; duration: 1100; easing.type: Easing.InOutSine }
                    OpacityAnimator { target: logo; from: 1.0; to: 0.7; duration: 1100; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    ScaleAnimator { target: logo; from: 1.06; to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                    OpacityAnimator { target: logo; from: 0.7; to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                }
            }
        }

        OpacityAnimator on opacity {
            from: 0
            to: 1
            duration: 600
            easing.type: Easing.OutCubic
        }
    }
}
