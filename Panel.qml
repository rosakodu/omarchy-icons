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
        var allGroups = []
        for (var i = 0; i < Catalog.catalog.length; i++) {
            allGroups.push(Catalog.catalog[i])
        }

        // Collect all theme identifiers defined in the catalog
        var catalogThemeMap = {}
        for (var c = 0; c < Catalog.catalog.length; c++) {
            var grp = Catalog.catalog[c]
            if (grp && grp.variants) {
                for (var v = 0; v < grp.variants.length; v++) {
                    catalogThemeMap[grp.variants[v].theme] = true
                }
            }
        }

        // Discover custom or locally installed themes on the user's system
        var customVariants = []
        var ignored = {
            "default": true,
            "hicolor": true,
            "0-active-theme": true,
            "locolor": true,
            "HighContrast": true,
            "AdwaitaLegacy": true
        }

        for (var t = 0; t < root.installedThemes.length; t++) {
            var themeName = root.installedThemes[t]
            if (!ignored[themeName] && !catalogThemeMap[themeName] && themeName.indexOf("0-active-theme") === -1) {
                customVariants.push({
                    name: themeName,
                    theme: themeName
                })
            }
        }

        if (customVariants.length > 0) {
            allGroups.push({
                name: "Custom / Other Themes",
                package: null,
                description: "Locally installed icon themes detected on your system",
                variants: customVariants
            })
        }

        var q = root.searchText.trim().toLowerCase()
        if (q === "") return allGroups
        var result = []
        for (var k = 0; k < allGroups.length; k++) {
            var group = allGroups[k]
            if (String(group.name || "").toLowerCase().indexOf(q) !== -1 ||
                String(group.description || "").toLowerCase().indexOf(q) !== -1) {
                result.push(group)
                continue
            }
            var matchedVariants = []
            for (var j = 0; j < group.variants.length; j++) {
                if (String(group.variants[j].name || "").toLowerCase().indexOf(q) !== -1 ||
                    String(group.variants[j].theme || "").toLowerCase().indexOf(q) !== -1)
                    matchedVariants.push(group.variants[j])
            }
            if (matchedVariants.length > 0) {
                var filtered = {}
                for (var key in group) filtered[key] = group[key]
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
            + 'LINK="$HOME/.local/share/icons/0-active-theme"; '
            + 'NEW_DIR="$HOME/.local/share/icons/0-active-theme-data-$$"; '
            + 'cleanup_stale() { '
            + '  for d in "$HOME/.local/share/icons"/0-active-theme-data-* "$HOME/.local/share/icons"/0-active-theme-new-* "$HOME/.local/share/icons"/0-active-theme.tmp* "$HOME/.local/share/icons"/0-active-theme.atomic-tmp* "$HOME/.local/share/icons"/0-active-theme.old*; do '
            + '    if [ -d "$d" ] || [ -L "$d" ]; then '
            + '      [ "$d" != "$LINK" ] && [ "$d" != "$NEW_DIR" ] && rm -rf "$d" 2>/dev/null || true; '
            + '    fi; '
            + '  done; '
            + '}; '
            + 'cleanup_stale; '
            + 'rm -rf "$NEW_DIR"; '
            + 'mkdir -p "$NEW_DIR/apps"; '
            + 'for pdir in /usr/share/pixmaps "$HOME/.local/share/pixmaps" "$HOME/.local/share/applications/icons"; do '
            + '  [ -d "$pdir" ] && cp -as "$pdir"/* "$NEW_DIR/apps/" 2>/dev/null || true; '
            + 'done; '
            + 'for hbase in /usr/share/icons/hicolor "$HOME/.local/share/icons/hicolor"; do '
            + '  if [ -d "$hbase" ]; then '
            + '    find "$hbase" ! -type d \( -name "*.svg" -o -name "*.png" \) \( -path "*/apps/*" -o -path "*/applications/*" \) -exec cp -asf -t "$NEW_DIR/apps/" {} + 2>/dev/null || true; '
            + '  fi; '
            + 'done; '
            + 'resolve_parents() { '
            + '  local t="$1"; '
            + '  for b in "$HOME/.local/share/icons" "/usr/share/icons" "$HOME/.icons"; do '
            + '    if [ -f "$b/$t/index.theme" ]; then '
            + '      local parents; '
            + '      parents=$(grep -E "^Inherits=" "$b/$t/index.theme" | cut -d= -f2 | tr "," " "); '
            + '      for suffix in "-Dark" "-dark" "-Light" "-light"; do '
            + '        if [[ "$t" == *"$suffix"* ]]; then '
            + '          local base="${t%$suffix}"; '
            + '          [ -n "$base" ] && [ "$base" != "$t" ] && parents="$parents $base"; '
            + '        fi; '
            + '      done; '
            + '      for p in $parents; do '
            + '        [ "$p" = "hicolor" ] && continue; '
            + '        echo "$p"; '
            + '        resolve_parents "$p"; '
            + '      done; '
            + '      break; '
            + '    fi; '
            + '  done; '
            + '}; '
            + 'link_dir_apps() { '
            + '  local src="$1"; '
            + '  [ ! -d "$src" ] && return; '
            + '  for d in $(find "$src" -type d \( -name "apps" -o -name "applications" -o -path "*/apps/*" -o -path "*/applications/*" \) 2>/dev/null | sort -V); do '
            + '    cp -asf "$d"/* "$NEW_DIR/apps/" 2>/dev/null || true; '
            + '  done; '
            + '}; '
            + 'PARENT_LIST=$(resolve_parents "$THEME" 2>/dev/null | tac | awk "!seen[$0]++" | tac); '
            + 'for p in $PARENT_LIST; do '
            + '  for pb in "$HOME/.local/share/icons" "/usr/share/icons" "$HOME/.icons"; do '
            + '    link_dir_apps "$pb/$p"; '
            + '  done; '
            + 'done; '
            + 'for b in "$HOME/.local/share/icons" "/usr/share/icons" "$HOME/.icons"; do '
            + '  link_dir_apps "$b/$THEME"; '
            + 'done; '
            + 'find "$NEW_DIR/apps" -mindepth 1 -type d -exec rm -rf {} + 2>/dev/null || true; '
            + 'rm -f "$NEW_DIR/apps/"*-symbolic.* "$NEW_DIR/apps/"*symbolic-spot.* 2>/dev/null || true; '
            + 'make_alias() { '
            + '  local r="$1"; local a="$2"; '
            + '  [ "$r" = "$a" ] && return; '
            + '  for ext in svg png; do '
            + '    local src="$NEW_DIR/apps/$r.$ext"; '
            + '    if [ -e "$src" ]; then '
            + '      local real; '
            + '      real=$(realpath -e "$src" 2>/dev/null || true); '
            + '      if [ -n "$real" ] && [ -f "$real" ]; then '
            + '        ln -sf "$real" "$NEW_DIR/apps/$a.$ext" 2>/dev/null || true; '
            + '      fi; '
            + '    fi; '
            + '  done; '
            + '}; '
            + 'make_alias "com.visualstudio.code" "code"; '
            + 'make_alias "com.visualstudio.code" "vscode"; '
            + 'make_alias "visual-studio-code" "code"; '
            + 'make_alias "visual-studio-code" "vscode"; '
            + 'make_alias "visualstudiocode" "code"; '
            + 'make_alias "visualstudiocode" "vscode"; '
            + 'make_alias "vscode" "code"; '
            + 'make_alias "code" "vscode"; '
            + 'make_alias "google-chrome" "chrome"; '
            + 'make_alias "chrome" "google-chrome"; '
            + 'make_alias "calligrakrita" "krita"; '
            + 'make_alias "krita" "org.kde.krita"; '
            + 'make_alias "org.kde.krita" "krita"; '
            + 'make_alias "org.gnome.nautilus" "org.gnome.Nautilus"; '
            + 'make_alias "org.gnome.Nautilus" "org.gnome.nautilus"; '
            + 'make_alias "org.gnome.nautilus" "file-manager"; '
            + 'make_alias "org.gnome.nautilus" "system-file-manager"; '
            + 'make_alias "file-manager" "org.gnome.Nautilus"; '
            + 'make_alias "system-file-manager" "org.gnome.Nautilus"; '
            + 'make_alias "user-file-manager" "org.gnome.Nautilus"; '
            + 'make_alias "dde-file-manager" "org.gnome.Nautilus"; '
            + 'make_alias "file-manager" "nautilus"; '
            + 'make_alias "system-file-manager" "nautilus"; '
            + 'make_alias "com.mitchellh.ghostty" "ghostty"; '
            + 'make_alias "ghostty" "com.mitchellh.ghostty"; '
            + 'make_alias "discord" "com.discordapp.Discord"; '
            + 'make_alias "discord" "omarchy-discord"; '
            + 'make_alias "omarchy-discord" "discord"; '
            + 'make_alias "org.telegram.desktop" "telegram"; '
            + 'make_alias "org.telegram.desktop" "org.telegram"; '
            + 'make_alias "telegram" "org.telegram.desktop"; '
            + 'make_alias "telegram" "org.telegram"; '
            + 'make_alias "ru.linux_gaming.PortProtonQt" "portproton"; '
            + 'make_alias "ru.linux_gaming.PortProtonQt" "PortProton"; '
            + 'make_alias "portproton" "ru.linux_gaming.PortProtonQt"; '
            + 'for f in "$NEW_DIR/apps/"*; do [ ! -e "$f" ] && rm -f "$f" 2>/dev/null || true; done; '
            + 'rm -rf "$LINK.old" 2>/dev/null || true; '
            + 'if [ -d "$LINK" ] || [ -L "$LINK" ]; then mv "$LINK" "$LINK.old" 2>/dev/null || rm -rf "$LINK" 2>/dev/null || true; fi; '
            + 'mv "$NEW_DIR" "$LINK" 2>/dev/null || (mkdir -p "$LINK" && cp -a "$NEW_DIR"/* "$LINK"/ 2>/dev/null) || true; '
            + 'mkdir -p "$HOME/.icons" 2>/dev/null || true; '
            + 'ln -sfn "$LINK" "$HOME/.icons/0-active-theme" 2>/dev/null || true; '
            + 'rm -rf "$LINK.old" "$NEW_DIR" 2>/dev/null || true; '
            + 'cleanup_stale; '
            + 'gsettings set org.gnome.desktop.interface icon-theme "$THEME" 2>/dev/null || true; '
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
            + 'done'
        applyProcess.command = ["bash", "-c", script, themeName]
        applyProcess.running = true
    }

    function installPackage(packageName) {
        if (root.installing || root.applying || !root.isAllowedPackage(packageName)) return
        root.installing = true
        root.operatingPackage = packageName
        root.statusMessage = "Installing " + packageName + "…"
        var cmd = 'if [ -f /var/lib/pacman/db.lck ] && ! pgrep -x pacman >/dev/null; then rm -f /var/lib/pacman/db.lck 2>/dev/null || true; fi; '
            + 'pacman -S --noconfirm --needed "$0" 2>&1'
        installProcess.command = ["pkexec", "bash", "-c", cmd, packageName]
        installProcess.running = true
    }

    property bool resetToAdwaitaOnRemove: false

    function packageContainsCurrentTheme(packageName) {
        if (!packageName) return false
        for (var i = 0; i < Catalog.catalog.length; i++) {
            var item = Catalog.catalog[i]
            if (item.package === packageName) {
                if (item.variants) {
                    for (var v = 0; v < item.variants.length; v++) {
                        if (item.variants[v].theme === root.currentTheme) {
                            return true
                        }
                    }
                }
                if (item.theme === root.currentTheme) {
                    return true
                }
            }
        }
        return false
    }

    function removePackage(packageName) {
        if (root.installing || root.applying || !root.isAllowedPackage(packageName)) return
        var isCurrent = root.packageContainsCurrentTheme(packageName)
        root.resetToAdwaitaOnRemove = isCurrent
        root.installing = true
        root.operatingPackage = packageName
        root.statusMessage = isCurrent ? "Removing " + packageName + " & switching theme…" : "Removing " + packageName + "…"
        var cmd = 'if [ -f /var/lib/pacman/db.lck ] && ! pgrep -x pacman >/dev/null; then rm -f /var/lib/pacman/db.lck 2>/dev/null || true; fi; '
            + 'pkgs=("$0"); '
            + 'if [ "$0" = "tela-circle-icon-theme-all" ]; then '
            + '  for p in $(pacman -Qq 2>/dev/null | grep "^tela-circle-icon-theme"); do pkgs+=("$p"); done; '
            + 'fi; '
            + 'pacman -Rns --noconfirm "${pkgs[@]}" 2>&1 || pacman -Rs --noconfirm "${pkgs[@]}" 2>&1 || pacman -R --noconfirm "${pkgs[@]}" 2>&1'
        removeProcess.command = ["pkexec", "bash", "-c", cmd, packageName]
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

            // If current theme is no longer present on disk, safely apply best available fallback
            if (root.currentTheme && root.currentTheme !== "" && root.installedThemes.length > 0 && root.installedThemes.indexOf(root.currentTheme) === -1) {
                var fallback = "Adwaita"
                if (root.installedThemes.indexOf("Tela-circle-manjaro") !== -1) {
                    fallback = "Tela-circle-manjaro"
                } else if (root.installedThemes.indexOf("Papirus") !== -1) {
                    fallback = "Papirus"
                } else if (root.installedThemes.indexOf("Yaru") !== -1) {
                    fallback = "Yaru"
                } else if (root.installedThemes.indexOf("Adwaita") !== -1) {
                    fallback = "Adwaita"
                } else if (root.installedThemes.length > 0) {
                    fallback = root.installedThemes[0]
                }
                root.applyTheme(fallback)
            }
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
                if (sep > 0) {
                    var pkg = line.slice(0, sep)
                    var st = line.slice(sep + 1)
                    status[pkg] = st
                }
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
                root.statusMessage = "Theme applied!"
                var appLib = (root.shell && root.shell.appLibrary) ? root.shell.appLibrary : ((root.bar && root.bar.shell) ? root.bar.shell.appLibrary : (typeof shell !== "undefined" ? shell.appLibrary : null))
                if (appLib && typeof appLib.refreshIcons === "function") {
                    appLib.refreshIcons()
                }
            } else {
                root.statusMessage = "Apply failed"
                root.scanCurrentTheme()
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
                var err = String(installStderr.text || installStdout.text || "Install failed").trim().split("\n")[0]
                root.statusMessage = err.length > 0 ? err : "Install failed"
            }
            statusClearTimer.restart()
        }
        stdout: StdioCollector { id: installStdout; waitForEnd: true }
        stderr: StdioCollector { id: installStderr; waitForEnd: true }
    }

    property Process removeProcess: Process {
        onExited: function(exitCode) {
            root.installing = false
            root.operatingPackage = ""
            var needAdwaita = root.resetToAdwaitaOnRemove
            root.resetToAdwaitaOnRemove = false

            if (exitCode === 0) {
                root.statusMessage = needAdwaita ? "Removed. Reverted to Adwaita." : "Removed successfully"
                root.refreshAll()
                if (needAdwaita) {
                    root.applyTheme("Adwaita")
                }
            } else {
                var err = String(removeStderr.text || removeStdout.text || "Remove failed").trim().split("\n")[0]
                root.statusMessage = err.length > 0 ? err : "Remove failed"
                root.refreshAll()
                root.scanCurrentTheme()
            }
            statusClearTimer.restart()
        }
        stdout: StdioCollector { id: removeStdout; waitForEnd: true }
        stderr: StdioCollector { id: removeStderr; waitForEnd: true }
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
