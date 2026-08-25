// IconCatalog.js — Catalog of available icon themes for Omarchy
// Each entry maps to a pacman package with its theme variants.

.pragma library

// Icon theme catalog — each group represents a pacman package
// with one or more GTK icon theme variants inside it.
var catalog = [
    {
        name: "Papirus",
        package: "papirus-icon-theme",
        description: "Modern flat icon theme with material design colors",
        variants: [
            { name: "Papirus",       theme: "Papirus",       mode: "auto" },
            { name: "Papirus Dark",  theme: "Papirus-Dark",  mode: "dark" },
            { name: "Papirus Light", theme: "Papirus-Light", mode: "light" },
            { name: "ePapirus",      theme: "ePapirus",      mode: "light" },
            { name: "ePapirus Dark", theme: "ePapirus-Dark", mode: "dark" }
        ]
    },
    {
        name: "Tela Circle",
        package: "tela-circle-icon-theme-all",
        description: "Flat colorful design icon theme with round folders",
        variants: [
            { name: "Tela Circle",            theme: "Tela-circle",            mode: "auto" },
            { name: "Tela Circle Dark",       theme: "Tela-circle-dark",       mode: "dark" },
            { name: "Tela Circle Black",      theme: "Tela-circle-black",      mode: "dark" },
            { name: "Tela Circle Black Dark", theme: "Tela-circle-black-dark", mode: "dark" },
            { name: "Tela Circle Blue",       theme: "Tela-circle-blue",       mode: "auto" },
            { name: "Tela Circle Blue Dark",  theme: "Tela-circle-blue-dark",  mode: "dark" },
            { name: "Tela Circle Green",      theme: "Tela-circle-green",      mode: "auto" },
            { name: "Tela Circle Green Dark", theme: "Tela-circle-green-dark", mode: "dark" },
            { name: "Tela Circle Red",        theme: "Tela-circle-red",        mode: "auto" },
            { name: "Tela Circle Red Dark",   theme: "Tela-circle-red-dark",   mode: "dark" },
            { name: "Tela Circle Pink",       theme: "Tela-circle-pink",       mode: "auto" },
            { name: "Tela Circle Pink Dark",  theme: "Tela-circle-pink-dark",  mode: "dark" }
        ]
    },
    {
        name: "Pop",
        package: "pop-icon-theme",
        description: "System76 Pop icon theme",
        variants: [
            { name: "Pop",      theme: "Pop",      mode: "light" },
            { name: "Pop Dark", theme: "Pop-dark",  mode: "dark" }
        ]
    },
    {
        name: "Obsidian",
        package: "obsidian-icon-theme",
        description: "Dark, elegant icon theme inspired by obsidian stone",
        variants: [
            { name: "Obsidian", theme: "Obsidian", mode: "dark" }
        ]
    },
    {
        name: "Cosmic",
        package: "cosmic-icon-theme",
        description: "COSMIC desktop icon theme by System76",
        variants: [
            { name: "Cosmic", theme: "Cosmic", mode: "auto" }
        ]
    },
    {
        name: "Elementary",
        package: "elementary-icon-theme",
        description: "Icons from the elementary OS Pantheon desktop",
        variants: [
            { name: "elementary", theme: "elementary", mode: "auto" }
        ]
    },
    {
        name: "Yaru",
        package: null,
        description: "Ubuntu Yaru icons (pre-installed with Omarchy)",
        variants: [
            { name: "Yaru",                   theme: "Yaru",                   mode: "auto" },
            { name: "Yaru Dark",              theme: "Yaru-dark",              mode: "dark" },
            { name: "Yaru Blue",              theme: "Yaru-blue",              mode: "auto" },
            { name: "Yaru Blue Dark",         theme: "Yaru-blue-dark",         mode: "dark" },
            { name: "Yaru Magenta",           theme: "Yaru-magenta",           mode: "auto" },
            { name: "Yaru Magenta Dark",      theme: "Yaru-magenta-dark",      mode: "dark" },
            { name: "Yaru Purple",            theme: "Yaru-purple",            mode: "auto" },
            { name: "Yaru Purple Dark",       theme: "Yaru-purple-dark",       mode: "dark" },
            { name: "Yaru Red",               theme: "Yaru-red",              mode: "auto" },
            { name: "Yaru Red Dark",          theme: "Yaru-red-dark",          mode: "dark" },
            { name: "Yaru Sage",              theme: "Yaru-sage",              mode: "auto" },
            { name: "Yaru Sage Dark",         theme: "Yaru-sage-dark",         mode: "dark" },
            { name: "Yaru Olive",             theme: "Yaru-olive",             mode: "auto" },
            { name: "Yaru Olive Dark",        theme: "Yaru-olive-dark",        mode: "dark" },
            { name: "Yaru Prussian Green",    theme: "Yaru-prussiangreen",     mode: "auto" },
            { name: "Yaru Prussian Green Dark",theme: "Yaru-prussiangreen-dark",mode: "dark" },
            { name: "Yaru Warty Brown",       theme: "Yaru-wartybrown",        mode: "auto" },
            { name: "Yaru Warty Brown Dark",  theme: "Yaru-wartybrown-dark",   mode: "dark" },
            { name: "Yaru Yellow",            theme: "Yaru-yellow",            mode: "auto" },
            { name: "Yaru Yellow Dark",       theme: "Yaru-yellow-dark",       mode: "dark" }
        ]
    },
    {
        name: "Adwaita",
        package: null,
        description: "GNOME standard icons (pre-installed)",
        variants: [
            { name: "Adwaita", theme: "Adwaita", mode: "auto" }
        ]
    },
    {
        name: "Breeze",
        package: null,
        description: "KDE Breeze icons (pre-installed)",
        variants: [
            { name: "Breeze",      theme: "breeze",      mode: "light" },
            { name: "Breeze Dark", theme: "breeze-dark",  mode: "dark" }
        ]
    }
]

// Returns flat list of all variants with parent group metadata attached.
function allVariants() {
    var result = []
    for (var i = 0; i < catalog.length; i++) {
        var group = catalog[i]
        for (var j = 0; j < group.variants.length; j++) {
            var v = group.variants[j]
            result.push({
                groupName:   group.name,
                groupIndex:  i,
                package:     group.package,
                description: group.description,
                name:        v.name,
                theme:       v.theme,
                mode:        v.mode
            })
        }
    }
    return result
}
