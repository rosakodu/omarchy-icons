import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    // ------------------------------------------------------------------ open / close

    function open() {
        root.controller.show()
        root.refreshAll()
    }

    function close() {
        root.controller.hide()
    }

    function toggle() {
        if (root.opened) root.close()
        else root.open()
    }

    // ------------------------------------------------------------------ state

    property string currentTheme: ""
    property var installedThemes: []
    property var packageStatus: ({})
    property int expandedGroupIndex: -1

    property bool scanning: false
    property bool installing: false
    property bool applying: false
    property string applyingThemeName: ""
    property string statusMessage: ""
    property string operatingPackage: ""
    property string searchText: ""

    // ------------------------------------------------------------------ helpers

    readonly property var filteredCatalog: {
        var q = root.searchText.trim().toLowerCase()
        if (q === "") return Catalog.catalog
        var result = []
        for (var i = 0; i < Catalog.catalog.length; i++) {
            var group = Catalog.catalog[i]
            if (String(group.name || "").toLowerCase().indexOf(q) !== -1 ||
                String(group.description || "").toLowerCase().indexOf(q) !== -1) {
                result.push(group)
                continue
            }
            var matchedVariants = []
            for (var j = 0; j < group.variants.length; j++) {
                if (String(group.variants[j].name || "").toLowerCase().indexOf(q) !== -1)
                    matchedVariants.push(group.variants[j])
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

    readonly property var allowedPackages: [
        "papirus-icon-theme",
        "tela-circle-icon-theme-all",
        "pop-icon-theme",
        "cosmic-icon-theme",
        "elementary-icon-theme",
        "deepin-icon-theme",
        "oxygen-icons"
    ]

    function isAllowedPackage(pkg) {
        for (var i = 0; i < allowedPackages.length; i++)
            if (allowedPackages[i] === pkg) return true
        return false
    }

    function isThemeInstalled(themeName) {
        for (var i = 0; i < root.installedThemes.length; i++)
            if (root.installedThemes[i] === themeName) return true
        return false
    }

    function isPackageInstalled(packageName) {
        if (!packageName) return true
        return root.packageStatus[packageName] === "installed"
    }

    function isThemeActive(themeName) {
        return root.currentTheme === themeName
    }

    function toggleGroup(index) {
        root.expandedGroupIndex = (root.expandedGroupIndex === index) ? -1 : index
    }

    function isGroupExpanded(index) {
        return root.expandedGroupIndex === index
    }

    // ------------------------------------------------------------------ actions

    function refreshAll() {
        root.scanCurrentTheme()
        root.scanInstalledThemes()
        root.scanPackages()
    }

    function scanCurrentTheme() {
        currentThemeProcess.command = ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"]
        currentThemeProcess.running = true
    }

    function scanInstalledThemes() {
        var script = "for d in /usr/share/icons/*/; do n=$(basename \"$d\"); [ -f \"$d/index.theme\" ] && echo \"$n\"; done; "
            + "for d in \"$HOME/.local/share/icons\"/*/; do n=$(basename \"$d\"); [ -f \"$d/index.theme\" ] && echo \"$n\"; done; "
            + "for d in \"$HOME/.icons\"/*/; do n=$(basename \"$d\"); [ -f \"$d/index.theme\" ] && echo \"$n\"; done"
        installedThemesProcess.command = ["bash", "-c", script]
        installedThemesProcess.running = true
    }

    function scanPackages() {
        root.scanning = true
        var script = ""
        for (var i = 0; i < allowedPackages.length; i++) {
            var pkg = allowedPackages[i]
            script += "if pacman -Q '" + pkg + "' &>/dev/null; then echo '" + pkg + "|installed'; else echo '" + pkg + "|not-installed'; fi\n"
        }
        packageCheckProcess.command = ["bash", "-c", script]
        packageCheckProcess.running = true
    }

    function applyTheme(themeName) {
        if (root.applying || root.installing) return
        if (!/^[A-Za-z0-9_-]+$/.test(themeName)) {
            root.statusMessage = "Invalid theme name"
            statusClearTimer.restart()
            return
        }
        root.applying = true
        root.applyingThemeName = themeName
        root.currentTheme = themeName
        root.statusMessage = "Applying " + themeName + "…"

        var script = 'THEME="$0"; '
            + 'gsettings set org.gnome.desktop.interface icon-theme "$THEME"; '
            + 'mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.icons/default"; '
            + 'printf "[Settings]\\ngtk-icon-theme-name=%s\\n" "$THEME" > "$HOME/.config/gtk-3.0/settings.ini"; '
            + 'printf "[Settings]\\ngtk-icon-theme-name=%s\\n" "$THEME" > "$HOME/.config/gtk-4.0/settings.ini"; '
            + 'printf "[Icon Theme]\\nInherits=%s\\n" "$THEME" > "$HOME/.icons/default/index.theme"; '
            + 'if [ -d "$HOME/.local/state/omarchy/current/theme" ]; then '
            + '  echo "$THEME" > "$HOME/.local/state/omarchy/current/theme/icons.theme" 2>/dev/null || true; '
            + 'fi; '
            + 'if command -v kwriteconfig6 &>/dev/null; then '
            + '  kwriteconfig6 --file kdeglobals --group Icons --key Theme "$THEME" 2>/dev/null || true; '
            + 'elif command -v kwriteconfig5 &>/dev/null; then '
            + '  kwriteconfig5 --file kdeglobals --group Icons --key Theme "$THEME" 2>/dev/null || true; '
            + 'fi; '
            + 'if [ -f "$HOME/.config/kdeglobals" ]; then '
            + '  sed -i -E \'/^\\[Icons\\]/,/^\\[/ s/^Theme=.*/Theme=\'"$THEME"\'/\' "$HOME/.config/kdeglobals" 2>/dev/null || true; '
            + 'fi; '
            + 'for qfile in "$HOME/.config/qt5ct/qt5ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"; do '
            + '  if [ -f "$qfile" ]; then '
            + '    sed -i -E \'s/^icon_theme=.*/icon_theme=\'"$THEME"\'/\' "$qfile" 2>/dev/null || true; '
            + '  fi; '
            + 'done; '
            + 'DEST="$HOME/.local/share/icons/0-active-theme"; '
            + 'rm -rf "$DEST" "$HOME/.icons/0-active-theme"; mkdir -p "$DEST/apps"; '
            + 'for png in /usr/share/pixmaps/*.png; do '
            + '  [ -f "$png" ] || continue; '
            + '  name=$(basename "$png" .png); '
            + '  b64=$(base64 -w0 "$png"); '
            + '  printf "<svg xmlns=\\"http://www.w3.org/2000/svg\\" xmlns:xlink=\\"http://www.w3.org/1999/xlink\\" width=\\"512\\" height=\\"512\\" viewBox=\\"0 0 512 512\\"><image width=\\"512\\" height=\\"512\\" xlink:href=\\"data:image/png;base64,%s\\"/></svg>\\n" "$b64" > "$DEST/apps/$name.svg"; '
            + 'done; '
            + 'for hdir in /usr/share/icons/hicolor/scalable/apps /usr/share/icons/hicolor/512x512/apps /usr/share/icons/hicolor/256x256/apps /usr/share/icons/hicolor/128x128/apps /usr/share/icons/hicolor/64x64/apps /usr/share/icons/hicolor/48x48/apps; do '
            + '  if [ -d "$hdir" ]; then cp -as "$hdir"/* "$DEST/apps/" 2>/dev/null || true; fi; '
            + 'done; '
            + 'ICON_BASES=("$HOME/.local/share/icons" "/usr/share/icons" "$HOME/.icons"); '
            + 'CANDIDATE_THEMES=("$THEME"); '
            + '[[ "$THEME" == *-* ]] && CANDIDATE_THEMES+=("${THEME%-*}"); '
            + '[[ "$THEME" == *_* ]] && CANDIDATE_THEMES+=("${THEME%_*}"); '
            + 'CANDIDATE_THEMES+=("${THEME%%-*}"); '
            + 'for (( idx=0; idx<${#CANDIDATE_THEMES[@]}; idx++ )); do '
            + '  t="${CANDIDATE_THEMES[idx]}"; '
            + '  for b in "${ICON_BASES[@]}"; do '
            + '    if [ -f "$b/$t/index.theme" ]; then '
            + '      inh=$(grep -E "^Inherits=" "$b/$t/index.theme" 2>/dev/null | cut -d= -f2 | tr "," " "); '
            + '      for p in $inh; do '
            + '        p=$(echo "$p" | tr -d " "); '
            + '        if [ -n "$p" ] && [ "$p" != "hicolor" ]; then '
            + '          found=0; for ex in "${CANDIDATE_THEMES[@]}"; do [[ "$ex" == "$p" ]] && found=1 && break; done; '
            + '          [ $found -eq 0 ] && CANDIDATE_THEMES+=("$p"); '
            + '        fi; '
            + '      done; '
            + '    fi; '
            + '  done; '
            + 'done; '
            + 'for (( i=${#CANDIDATE_THEMES[@]}-1; i>=0; i-- )); do '
            + '  t="${CANDIDATE_THEMES[i]}"; '
            + '  for b in "${ICON_BASES[@]}"; do '
            + '    tdir="$b/$t"; '
            + '    if [ -d "$tdir" ]; then '
            + '      for sub in "256x256/apps" "scalable/apps" "64x64/apps" "48x48/apps" "128x128/apps" "32x32/apps" "apps" "scalable/applications" "base/64x64/apps" "base/128x128/apps"; do '
            + '        if [ -d "$tdir/$sub" ]; then '
            + '          real=$(realpath -e "$tdir/$sub" 2>/dev/null); '
            + '          if [ -n "$real" ] && [ -d "$real" ]; then '
            + '            find -L "$real" -maxdepth 1 \\( -name "*.svg" -o -name "*.png" \\) -exec cp -asf {} "$DEST/apps/" \\; 2>/dev/null || true; '
            + '          fi; '
            + '        fi; '
            + '      done; '
            + '    fi; '
            + '  done; '
            + 'done'
        applyProcess.command = ["bash", "-c", script, themeName]
        applyProcess.running = true
    }

    function installPackage(packageName) {
        if (root.installing || root.applying || !root.isAllowedPackage(packageName)) return
        root.installing = true
        root.operatingPackage = packageName
        root.statusMessage = "Installing " + packageName + "…"
        installProcess.command = ["pkexec", "pacman", "-S", "--noconfirm", packageName]
        installProcess.running = true
    }

    function removePackage(packageName) {
        if (root.installing || root.applying || !root.isAllowedPackage(packageName)) return
        root.installing = true
        root.operatingPackage = packageName
        root.statusMessage = "Removing " + packageName + "…"
        removeProcess.command = ["pkexec", "pacman", "-R", "--noconfirm", packageName]
        removeProcess.running = true
    }

    // ------------------------------------------------------------------ processes

    property Process currentThemeProcess: Process {
        onExited: function(exitCode) {
            var raw = String(currentThemeStdout.text || "").trim()
            if (exitCode === 0 && raw !== "") {
                var lines = raw.split("\n")
                var lastLine = lines[lines.length - 1].trim().replace(/^'|'$/g, "")
                if (lastLine !== "") root.currentTheme = lastLine
            }
        }
        stdout: StdioCollector { id: currentThemeStdout; waitForEnd: true }
    }

    property Process installedThemesProcess: Process {
        onExited: function(exitCode) {
            if (exitCode !== 0) return
            var out = String(installedThemesStdout.text || "").trim()
            if (out === "") { root.installedThemes = []; return }
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
            var out = String(packageCheckStdout.text || "").trim()
            if (out === "") return
            var status = {}
            var lines = out.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (line === "") continue
                var sep = line.indexOf("|")
                if (sep < 0) continue
                status[line.substring(0, sep)] = line.substring(sep + 1).trim()
            }
            root.packageStatus = status
        }
        stdout: StdioCollector { id: packageCheckStdout; waitForEnd: true }
    }

    property Process applyProcess: Process {
        onExited: function(exitCode) {
            root.applying = false
            root.applyingThemeName = ""
            if (exitCode === 0) {
                root.statusMessage = "Theme applied! Reloading…"
                restartShellTimer.restart()
            } else {
                root.statusMessage = "Apply failed"
                root.scanCurrentTheme()
            }
            statusClearTimer.restart()
        }
        stdout: StdioCollector { id: applyStdout; waitForEnd: true }
    }

    property Timer restartShellTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["bash", "-c", "rm -rf \"$HOME/.cache/quickshell/qmlcache\" \"$HOME/.cache/quickshell\"/qtpipelinecache-*; omarchy-restart-shell"])
        }
    }

    property Process installProcess: Process {
        onExited: function(exitCode) {
            root.installing = false
            root.operatingPackage = ""
            if (exitCode === 0) {
                root.statusMessage = "Installed successfully"
                root.refreshAll()
                if (root.currentTheme && root.currentTheme.length > 0) {
                    root.applyTheme(root.currentTheme)
                }
            } else {
                root.statusMessage = "Install failed"
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
                root.statusMessage = "Remove failed"
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

    Component.onCompleted: root.refreshAll()

    onOpenedChanged: {
        if (opened) root.refreshAll()
    }

    // ------------------------------------------------------------------ UI

    KeyboardPanel {
        id: panelWindow
        anchorItem: root.anchorItem
        bar: root.bar
        owner: root.barIdentity
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panelWindow.fittedContentWidth(Style.space(420))
        contentHeight: panelWindow.fittedContentHeight(Style.space(560))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            blocked: searchField.activeFocus
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }

            ColumnLayout {
                anchors.fill: parent
                spacing: Style.space(10)

                // ==================== HERO ====================
                PanelHero {
                    Layout.fillWidth: true
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
                    color: root.statusMessage.indexOf("failed") !== -1 || root.statusMessage.indexOf("Please install") !== -1 ? Color.urgent : root.dimColor
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                PanelSeparator {
                    Layout.fillWidth: true
                    foreground: root.contentForeground
                }

                // ==================== SEARCH ====================
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "Search icon themes…"
                    text: root.searchText
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily
                    onTextChanged: root.searchText = text
                }

                // ==================== GROUP LIST ====================
                ListView {
                    id: groupList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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

                        width: groupList.width
                        spacing: 0

                        // ---- Group header row ----
                        Button {
                            id: groupButton
                            width: parent.width
                            text: group.name
                            iconText: expanded ? "\uf078" : "\uf054"
                            leftAlign: true
                            foreground: root.contentForeground
                            fontFamily: root.contentFontFamily

                            onClicked: root.toggleGroup(index)

                            // Status indicator on the right
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: Style.spacing.controlPaddingX
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !groupDelegate.pkgInstalled
                                text: root.installing && root.operatingPackage === group.package ? "⏳" : "📦"
                                font.pixelSize: Style.font.caption
                                color: root.dimColor
                            }
                        }

                        // ---- Expanded variant list ----
                        Column {
                            visible: groupDelegate.expanded
                            width: parent.width
                            spacing: 0

                            // Install/Remove button for the package
                            Button {
                                visible: group.package !== null
                                width: parent.width
                                leftAlign: true
                                enabled: !root.installing && !root.applying
                                foreground: root.contentForeground
                                fontFamily: root.contentFontFamily
                                text: {
                                    if (root.installing && root.operatingPackage === group.package) return "Working…"
                                    return groupDelegate.pkgInstalled ? "Remove package" : "Install package"
                                }
                                iconText: {
                                    if (root.installing && root.operatingPackage === group.package) return "\uf110"
                                    return groupDelegate.pkgInstalled ? "\uf1f8" : "\uf019"
                                }
                                iconSpinning: root.installing && root.operatingPackage === group.package

                                onClicked: {
                                    if (root.installing || root.applying) return
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

                            // ---- Variant rows ----
                            Repeater {
                                model: group.variants.length
                                delegate: Button {
                                    id: variantButton
                                    required property int index
                                    readonly property var variant: groupDelegate.group.variants[index]
                                    readonly property bool themeInstalled: root.isThemeInstalled(variant.theme)
                                    readonly property bool themeActive: root.isThemeActive(variant.theme)
                                    readonly property bool isApplyingThis: root.applying && root.applyingThemeName === variant.theme

                                    width: groupDelegate.width
                                    leftAlign: true
                                    enabled: !root.applying && !root.installing
                                    foreground: root.contentForeground
                                    fontFamily: root.contentFontFamily
                                    selected: themeActive

                                    text: variant.name
                                    iconText: isApplyingThis ? "\uf110" : (themeActive ? "\uf00c" : (themeInstalled ? "\uf111" : "\uf10c"))
                                    iconSpinning: isApplyingThis

                                    onClicked: {
                                        if (root.applying || root.installing) return
                                        if (themeActive) return
                                        if (themeInstalled || groupDelegate.pkgInstalled || groupDelegate.group.package === null) {
                                            root.applyTheme(variant.theme)
                                        } else {
                                            root.statusMessage = "Please install " + groupDelegate.group.name + " first"
                                            statusClearTimer.restart()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==================== FOOTER ====================
                PanelSeparator {
                    Layout.fillWidth: true
                    foreground: root.contentForeground
                }

                RowLayout {
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "Refresh"
                        iconText: "\uf021"
                        enabled: !root.applying && !root.installing
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
