// IconCatalog.js — Curated catalog of icon themes for Omarchy
// All downloadable packages come directly from Arch Linux official repositories (pacman).

.pragma library

var catalog = [
    {
        name: "Papirus",
        package: "papirus-icon-theme",
        description: "Modern flat icon theme with material design colors",
        variants: [
            { name: "Papirus Dark",  theme: "Papirus-Dark" },
            { name: "Papirus Light", theme: "Papirus-Light" }
        ]
    },
    {
        name: "Tela Circle",
        package: "tela-circle-icon-theme-all",
        description: "Flat colorful design icon theme with round folders",
        variants: [
            { name: "Tela Circle",            theme: "Tela-circle" },
            { name: "Tela Circle Dark",       theme: "Tela-circle-dark" },
            { name: "Tela Circle Light",      theme: "Tela-circle-light" },
            { name: "Tela Circle Black",      theme: "Tela-circle-black" },
            { name: "Tela Circle Black Dark", theme: "Tela-circle-black-dark" },
            { name: "Tela Circle Blue",       theme: "Tela-circle-blue" },
            { name: "Tela Circle Blue Dark",  theme: "Tela-circle-blue-dark" },
            { name: "Tela Circle Dracula",    theme: "Tela-circle-dracula" },
            { name: "Tela Circle Dracula Dark", theme: "Tela-circle-dracula-dark" },
            { name: "Tela Circle Green",      theme: "Tela-circle-green" },
            { name: "Tela Circle Green Dark", theme: "Tela-circle-green-dark" },
            { name: "Tela Circle Nord",       theme: "Tela-circle-nord" },
            { name: "Tela Circle Nord Dark",  theme: "Tela-circle-nord-dark" },
            { name: "Tela Circle Orange",     theme: "Tela-circle-orange" },
            { name: "Tela Circle Orange Dark",theme: "Tela-circle-orange-dark" },
            { name: "Tela Circle Pink",       theme: "Tela-circle-pink" },
            { name: "Tela Circle Pink Dark",  theme: "Tela-circle-pink-dark" },
            { name: "Tela Circle Purple",     theme: "Tela-circle-purple" },
            { name: "Tela Circle Purple Dark",theme: "Tela-circle-purple-dark" },
            { name: "Tela Circle Red",        theme: "Tela-circle-red" },
            { name: "Tela Circle Red Dark",   theme: "Tela-circle-red-dark" },
            { name: "Tela Circle Yellow",     theme: "Tela-circle-yellow" },
            { name: "Tela Circle Yellow Dark",theme: "Tela-circle-yellow-dark" },
            { name: "Tela Circle Manjaro",    theme: "Tela-circle-manjaro" },
            { name: "Tela Circle Ubuntu",     theme: "Tela-circle-ubuntu" }
        ]
    },
    {
        name: "Pop",
        package: "pop-icon-theme",
        description: "System76 Pop!_OS official icon theme",
        variants: [
            { name: "Pop", theme: "Pop" }
        ]
    },
    {
        name: "Deepin / Bloom",
        package: "deepin-icon-theme",
        description: "Deepin Desktop elegant icon theme",
        variants: [
            { name: "Bloom",                theme: "bloom" },
            { name: "Bloom Dark",           theme: "bloom-dark" },
            { name: "Bloom Classic",        theme: "bloom-classic" },
            { name: "Bloom Classic Dark",   theme: "bloom-classic-dark" },
            { name: "Vintage",              theme: "vintage" },
            { name: "Sea",                  theme: "Sea" }
        ]
    },
    {
        name: "Cosmic",
        package: "cosmic-icon-theme",
        description: "COSMIC desktop icon theme by System76",
        variants: [
            { name: "Cosmic", theme: "Cosmic" }
        ]
    },
    {
        name: "Elementary",
        package: "elementary-icon-theme",
        description: "Icons from the elementary OS Pantheon desktop",
        variants: [
            { name: "elementary", theme: "elementary" }
        ]
    },
    {
        name: "Oxygen",
        package: "oxygen-icons",
        description: "Classic detailed KDE Oxygen icon theme",
        variants: [
            { name: "Oxygen", theme: "oxygen" }
        ]
    },
    {
        name: "Yaru",
        package: null,
        description: "Ubuntu Yaru icons (pre-installed with Omarchy)",
        variants: [
            { name: "Yaru",                   theme: "Yaru" },
            { name: "Yaru Dark",              theme: "Yaru-dark" },
            { name: "Yaru Blue",              theme: "Yaru-blue" },
            { name: "Yaru Blue Dark",         theme: "Yaru-blue-dark" },
            { name: "Yaru Magenta",           theme: "Yaru-magenta" },
            { name: "Yaru Magenta Dark",      theme: "Yaru-magenta-dark" },
            { name: "Yaru Purple",            theme: "Yaru-purple" },
            { name: "Yaru Purple Dark",       theme: "Yaru-purple-dark" },
            { name: "Yaru Red",               theme: "Yaru-red" },
            { name: "Yaru Red Dark",          theme: "Yaru-red-dark" },
            { name: "Yaru Sage",              theme: "Yaru-sage" },
            { name: "Yaru Sage Dark",         theme: "Yaru-sage-dark" },
            { name: "Yaru Olive",             theme: "Yaru-olive" },
            { name: "Yaru Olive Dark",        theme: "Yaru-olive-dark" },
            { name: "Yaru Prussian Green",    theme: "Yaru-prussiangreen" },
            { name: "Yaru Prussian Green Dark",theme: "Yaru-prussiangreen-dark" },
            { name: "Yaru Warty Brown",       theme: "Yaru-wartybrown" },
            { name: "Yaru Warty Brown Dark",  theme: "Yaru-wartybrown-dark" },
            { name: "Yaru Yellow",            theme: "Yaru-yellow" },
            { name: "Yaru Yellow Dark",       theme: "Yaru-yellow-dark" }
        ]
    },
    {
        name: "Adwaita",
        package: null,
        description: "GNOME standard icons (pre-installed)",
        variants: [
            { name: "Adwaita", theme: "Adwaita" }
        ]
    },
    {
        name: "Breeze",
        package: null,
        description: "KDE Breeze icons (pre-installed)",
        variants: [
            { name: "Breeze",      theme: "breeze" },
            { name: "Breeze Dark", theme: "breeze-dark" }
        ]
    }
]

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
                theme:       v.theme
            })
        }
    }
    return result
}
