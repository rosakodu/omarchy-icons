import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "IconCatalog.js" as Catalog

Panel {
    id: root
    moduleName: "icons"
    ipcTarget: "icons"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    readonly property var barIdentity: hostWidget || root

    readonly property color contentForeground: bar ? bar.foreground : Color.foreground
    readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property color panelBackground: Color.popups.background
    readonly property color dimColor: Qt.darker(contentForeground, 1.4)

    // ------------------------------------------------------------------ state

    // Current GTK icon theme (read from gsettings on open).
    property string currentTheme: ""

    // Installed icon theme directories in /usr/share/icons etc.
    property var installedThemes: []

    // Package install status: packageName -> "installed" | "not-installed"
    property var packageStatus: ({})

    // Expanded group indices (which catalog groups are expanded).
    property var expandedGroups: ({})

    // Operation state
    property bool scanning: false
    property bool installing: false
    property bool applying: false
    property string statusMessage: ""
    property string operatingPackage: ""

    // Search / filter
    property string searchText: ""

    // Keyboard cursor
    property int selectedGroupIndex: 0
    property int selectedVariantIndex: -1
    property bool cursorActive: false

    // ------------------------------------------------------------------ helpers

    readonly property string helperPath: {
        // Resolve the helper script relative to this QML file.
        var url = Qt.resolvedUrl("icons-helper.sh")
        return String(url).replace(/^file:\/\//, "")
    }

    // Groups filtered by search text.
    readonly property var filteredCatalog: {
        var q = root.searchText.trim().toLowerCase()
        if (q === "") return Catalog.catalog
        var result = []
        for (var i = 0; i < Catalog.catalog.length; i++) {
            var group = Catalog.catalog[i]
            // Match group name or description
            if (String(group.name || "").toLowerCase().indexOf(q) !== -1 ||
                String(group.description || "").toLowerCase().indexOf(q) !== -1) {
                result.push(group)
                continue
            }
            // Match individual variant names
            var matchedVariants = []
            for (var j = 0; j < group.variants.length; j++) {
                if (String(group.variants[j].name || "").toLowerCase().indexOf(q) !== -1) {
                    matchedVariants.push(group.variants[j])
                }
            }
            if (matchedVariants.length > 0) {
                var filtered = {}
                for (var k in group) filtered[k] = group[k]
                filtered.variants = matchedVariants
                result.push(filtered)
            }
        }
        return result
    }

    function isThemeInstalled(themeName) {
        for (var i = 0; i < root.installedThemes.length; i++) {
            if (root.installedThemes[i] === themeName) return true
        }
        return false
    }

    function isPackageInstalled(packageName) {
        if (!packageName) return true  // null package = pre-installed
        return root.packageStatus[packageName] === "installed"
    }

    function isThemeActive(themeName) {
        return root.currentTheme === themeName
    }

    function toggleGroup(index) {
        var next = {}
        for (var k in root.expandedGroups) next[k] = root.expandedGroups[k]
        if (next[index]) delete next[index]
        else next[index] = true
        root.expandedGroups = next
    }

    function isGroupExpanded(index) {
        return root.expandedGroups[index] === true
    }

    // Mode badge color
    function modeColor(mode) {
        if (mode === "dark") return Qt.darker(root.contentForeground, 1.8)
        if (mode === "light") return Qt.lighter(root.contentForeground, 1.8)
        return "transparent"
    }

    // Mode badge text color
    function modeTextColor(mode) {
        if (mode === "dark") return Qt.lighter(root.contentForeground, 1.5)
        if (mode === "light") return Qt.darker(root.contentForeground, 2.0)
        return root.dimColor
    }

    // ------------------------------------------------------------------ actions

    function refreshAll() {
        root.scanCurrentTheme()
        root.scanInstalledThemes()
        root.scanPackages()
    }

    function scanCurrentTheme() {
        currentThemeProcess.command = ["bash", root.helperPath, "current"]
        currentThemeProcess.running = true
    }

    function scanInstalledThemes() {
        installedThemesProcess.command = ["bash", root.helperPath, "list-installed"]
        installedThemesProcess.running = true
    }

    function scanPackages() {
        root.scanning = true
        packageCheckProcess.command = ["bash", root.helperPath, "check-all"]
        packageCheckProcess.running = true
    }

    function applyTheme(themeName) {
        if (root.applying) return
        root.applying = true
        root.statusMessage = "Applying " + themeName + "…"
        applyProcess.command = ["bash", root.helperPath, "apply", themeName]
        applyProcess.running = true
    }

    function installPackage(packageName) {
        if (root.installing) return
        root.installing = true
        root.operatingPackage = packageName
        root.statusMessage = "Installing " + packageName + "…"
        installProcess.command = ["bash", root.helperPath, "install", packageName]
        installProcess.running = true
    }

    function removePackage(packageName) {
        if (root.installing) return
        root.installing = true
        root.operatingPackage = packageName
        root.statusMessage = "Removing " + packageName + "…"
        removeProcess.command = ["bash", root.helperPath, "remove", packageName]
        removeProcess.running = true
    }

    // ------------------------------------------------------------------ processes

    property Process currentThemeProcess: Process {
        onExited: function(exitCode) {
            var out = String(currentThemeStdout.text || "").trim()
            if (exitCode === 0 && out !== "") root.currentTheme = out
        }
        stdout: StdioCollector { id: currentThemeStdout; waitForEnd: true }
    }

    property Process installedThemesProcess: Process {
        onExited: function(exitCode) {
            if (exitCode !== 0) return
            var out = String(installedThemesStdout.text || "").trim()
            if (out === "") { root.installedThemes = []; return }
            // Deduplicate
            var lines = out.split("\n")
            var unique = {}
            for (var i = 0; i < lines.length; i++) {
                var t = lines[i].trim()
                if (t !== "") unique[t] = true
            }
            root.installedThemes = Object.keys(unique).sort()
        }
        stdout: StdioCollector { id: installedThemesStdout; waitForEnd: true }
    }

    property Process packageCheckProcess: Process {
        onExited: function(exitCode) {
            root.scanning = false
            if (exitCode !== 0) return
            var out = String(packageCheckStdout.text || "").trim()
            if (out === "") return
            var status = {}
            var lines = out.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (line === "") continue
                var sep = line.indexOf("|")
                if (sep < 0) continue
                var pkg = line.substring(0, sep)
                var st = line.substring(sep + 1).trim()
                status[pkg] = st
            }
            root.packageStatus = status
        }
        stdout: StdioCollector { id: packageCheckStdout; waitForEnd: true }
    }

    property Process applyProcess: Process {
        onExited: function(exitCode) {
            root.applying = false
            if (exitCode === 0) {
                root.statusMessage = "Theme applied"
                root.scanCurrentTheme()
            } else {
                var err = String(applyStdout.text || "").trim()
                root.statusMessage = "Apply failed" + (err ? ": " + err : "")
            }
            statusClearTimer.restart()
        }
        stdout: StdioCollector { id: applyStdout; waitForEnd: true }
    }

    property Process installProcess: Process {
        onExited: function(exitCode) {
            root.installing = false
            root.operatingPackage = ""
            if (exitCode === 0) {
                root.statusMessage = "Installed successfully"
                root.refreshAll()
            } else {
                var err = String(installStdout.text || "").trim()
                root.statusMessage = "Install failed" + (err ? ": " + err.substring(0, 100) : "")
            }
            statusClearTimer.restart()
        }
        stdout: StdioCollector { id: installStdout; waitForEnd: true }
    }

    property Process removeProcess: Process {
        onExited: function(exitCode) {
            root.installing = false
            root.operatingPackage = ""
            if (exitCode === 0) {
                root.statusMessage = "Removed successfully"
                root.refreshAll()
            } else {
                var err = String(removeStdout.text || "").trim()
                root.statusMessage = "Remove failed" + (err ? ": " + err.substring(0, 100) : "")
            }
            statusClearTimer.restart()
        }
        stdout: StdioCollector { id: removeStdout; waitForEnd: true }
    }

    property Timer statusClearTimer: Timer {
        interval: 4000
        repeat: false
        onTriggered: root.statusMessage = ""
    }

    // ------------------------------------------------------------------ lifecycle

    onOpenedChanged: {
        if (opened) root.refreshAll()
    }

    // ------------------------------------------------------------------ UI

    property var anchorItemRef: anchorItem

    KeyboardPanel {
        id: panelWindow
        anchorItem: root.anchorItemRef
        bar: root.bar
        owner: root.barIdentity
        open: root.opened
        contentWidth: Style.space(380)
        contentHeight: panelWindow.fittedContentHeight(contentColumn.implicitHeight, Style.space(600))

        focusTarget: keyCatcher

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }
            onMoveRequested: function(dx, dy) {
                if (dy !== 0) {
                    root.cursorActive = true
                    root.selectedGroupIndex = Math.max(0, Math.min(root.selectedGroupIndex + dy, root.filteredCatalog.length - 1))
                }
            }
            onActivateRequested: {
                if (root.cursorActive && root.selectedGroupIndex >= 0 && root.selectedGroupIndex < root.filteredCatalog.length) {
                    root.toggleGroup(root.selectedGroupIndex)
                }
            }

            Column {
                id: contentColumn
                anchors.fill: parent
                spacing: Style.space(12)

                // ==================== HERO ====================
                PanelHero {
                    width: parent.width
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                    title: "Icon Themes"
                    meta: root.currentTheme !== "" ? root.currentTheme : "Loading…"
                    iconComponent: Component {
                        Text {
                            text: "\udb84\ude4b"
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.display
                        }
                    }
                }

                // ==================== STATUS MESSAGE ====================
                Text {
                    visible: root.statusMessage !== ""
                    text: root.statusMessage
                    color: root.statusMessage.indexOf("failed") !== -1 ? Color.urgent : root.dimColor
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: parent.width
                    elide: Text.ElideRight
                }

                PanelSeparator {
                    foreground: root.contentForeground
                }

                // ==================== SEARCH ====================
                TextField {
                    id: searchField
                    width: parent.width
                    placeholderText: "Search icon themes…"
                    text: root.searchText
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                    onTextChanged: root.searchText = text

                    // Prevent PanelKeyCatcher from consuming keys while typing
                    onActiveFocusChanged: keyCatcher.blocked = activeFocus
                }

                // ==================== GROUP LIST ====================
                ListView {
                    id: groupList
                    width: parent.width
                    height: Math.min(contentHeight, Style.space(420))
                    clip: true
                    spacing: Style.space(4)
                    model: root.filteredCatalog.length
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Column {
                        id: groupDelegate
                        required property int index
                        readonly property var group: root.filteredCatalog[index]
                        readonly property bool expanded: root.isGroupExpanded(index)
                        readonly property bool pkgInstalled: root.isPackageInstalled(group.package)
                        readonly property bool hasCursor: root.cursorActive && root.selectedGroupIndex === index

                        width: groupList.width
                        spacing: 0

                        // ---- Group header row ----
                        Button {
                            id: groupButton
                            width: parent.width
                            text: group.name
                            iconText: expanded ? "\uf078" : "\uf054"  // chevron down/right
                            leftAlign: true
                            hasCursor: groupDelegate.hasCursor
                            foreground: root.contentForeground
                            fontFamily: root.contentFontFamily
                            tooltipText: group.description

                            onClicked: root.toggleGroup(index)
                            onHovered: function(on) {
                                if (on) {
                                    root.cursorActive = true
                                    root.selectedGroupIndex = index
                                }
                            }

                            // Status pill on the right side
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: Style.spacing.controlPaddingX
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !groupDelegate.pkgInstalled
                                text: root.installing && root.operatingPackage === group.package ? "⏳" : "📦"
                                font.pixelSize: Style.font.caption
                                color: root.dimColor

                                ToolTip {
                                    visible: parent.visible && groupButton.hot
                                    text: "Package not installed"
                                    delay: 400
                                    padding: Style.spacing.controlPaddingY
                                    background: Rectangle {
                                        color: Color.tooltip.background
                                        radius: Style.cornerRadius
                                    }
                                    contentItem: Text {
                                        text: "Package not installed"
                                        color: Color.tooltip.text
                                        font.family: root.contentFontFamily
                                        font.pixelSize: Style.font.bodySmall
                                    }
                                }
                            }
                        }

                        // ---- Expanded variant list ----
                        Column {
                            visible: groupDelegate.expanded
                            width: parent.width
                            spacing: 0

                            // Install/Remove button for the package (when not pre-installed)
                            Button {
                                visible: group.package !== null
                                width: parent.width
                                leftAlign: true
                                foreground: root.contentForeground
                                fontFamily: root.contentFontFamily
                                text: {
                                    if (root.installing && root.operatingPackage === group.package) return "Working…"
                                    return groupDelegate.pkgInstalled ? "Remove package" : "Install package"
                                }
                                iconText: {
                                    if (root.installing && root.operatingPackage === group.package) return "\uf110" // spinner
                                    return groupDelegate.pkgInstalled ? "\uf1f8" : "\uf019" // trash or download
                                }
                                iconSpinning: root.installing && root.operatingPackage === group.package

                                onClicked: {
                                    if (root.installing) return
                                    if (groupDelegate.pkgInstalled)
                                        root.removePackage(group.package)
                                    else
                                        root.installPackage(group.package)
                                }
                            }

                            PanelSeparator {
                                visible: group.package !== null
                                foreground: root.contentForeground
                                strength: 0.06
                            }

                            // Description
                            Text {
                                width: parent.width
                                text: group.description
                                color: root.dimColor
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.caption
                                wrapMode: Text.Wrap
                                leftPadding: Style.spacing.controlPaddingX
                                topPadding: Style.space(6)
                                bottomPadding: Style.space(4)
                            }

                            // ---- Variant rows ----
                            Repeater {
                                model: group.variants.length
                                delegate: Button {
                                    id: variantButton
                                    required property int index
                                    readonly property var variant: groupDelegate.group.variants[index]
                                    readonly property bool themeInstalled: root.isThemeInstalled(variant.theme)
                                    readonly property bool themeActive: root.isThemeActive(variant.theme)

                                    width: groupDelegate.width
                                    leftAlign: true
                                    foreground: root.contentForeground
                                    fontFamily: root.contentFontFamily
                                    selected: themeActive

                                    text: variant.name
                                    iconText: themeActive ? "\uf00c" : (themeInstalled ? "\uf111" : "\uf10c")  // check, filled circle, empty circle

                                    onClicked: {
                                        if (themeActive) return  // already active
                                        if (themeInstalled) root.applyTheme(variant.theme)
                                        else if (groupDelegate.pkgInstalled) root.applyTheme(variant.theme)
                                        else root.statusMessage = "Install the package first"
                                    }

                                    // Mode badge on the right
                                    Rectangle {
                                        visible: variant.mode !== "auto"
                                        anchors.right: parent.right
                                        anchors.rightMargin: Style.spacing.controlPaddingX
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: modeBadgeText.implicitWidth + Style.space(10)
                                        height: modeBadgeText.implicitHeight + Style.space(4)
                                        radius: Style.cornerRadius
                                        color: root.modeColor(variant.mode)

                                        Text {
                                            id: modeBadgeText
                                            anchors.centerIn: parent
                                            text: variant.mode === "dark" ? "Dark" : "Light"
                                            color: root.modeTextColor(variant.mode)
                                            font.family: root.contentFontFamily
                                            font.pixelSize: Style.font.caption * 0.9
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==================== FOOTER ====================
                PanelSeparator {
                    foreground: root.contentForeground
                }

                Item {
                    width: parent.width
                    implicitHeight: footerRow.implicitHeight

                    Row {
                        id: footerRow
                        anchors.right: parent.right
                        spacing: Style.space(8)

                        Button {
                            text: "Refresh"
                            iconText: "\uf021"
                            foreground: root.contentForeground
                            fontFamily: root.contentFontFamily
                            iconSpinning: root.scanning
                            onClicked: root.refreshAll()
                        }
                    }
                }
            }
        }
    }
}
