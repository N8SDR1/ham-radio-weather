pragma Singleton
import QtQuick

// Central mood dictionary so tile titles/icons/accents stay consistent
// and easy to tweak in one place.
QtObject {
    id: moods

    // Returns {title, icon} based on outdoor °F
    function outdoor(f) {
        if (f === undefined || isNaN(f)) return { title: "Outdoor",       icon: "🌡" }
        if (f <= 20)                     return { title: "Deep Freeze",   icon: "🥶" }
        if (f <= 40)                     return { title: "Crisp",         icon: "🍂" }
        if (f <= 70)                     return { title: "Pleasant",      icon: "☀"  }
        if (f <= 85)                     return { title: "Toasty",        icon: "🌤" }
        if (f <= 95)                     return { title: "Scorcher",      icon: "🥵" }
        return                                   { title: "Melt Mode",    icon: "🫠" }
    }

    // Returns {title, icon} based on wind mph
    function wind(mph) {
        if (mph === undefined || isNaN(mph)) return { title: "Wind",             icon: "🌬" }
        if (mph < 2)                         return { title: "Still Air",        icon: "🍃" }
        if (mph < 10)                        return { title: "Breeze",           icon: "🌬" }
        if (mph < 20)                        return { title: "Windy",            icon: "💨" }
        if (mph < 35)                        return { title: "Gusty",            icon: "🚩" }
        if (mph < 50)                        return { title: "Howling",          icon: "🌪" }
        return                                       { title: "Antenna Swayer!", icon: "📡" }
    }

    // Returns {title, icon} based on lightning distance (mi) + strike count
    // Keeps ⚡ as the tile identity for the default/calm state.
    function lightning(distMi, count) {
        var n = count || 0
        if (n === 0)                         return { title: "All Clear",         icon: "⚡" }
        if (distMi === undefined || isNaN(distMi) || distMi > 25)
                                             return { title: "Distant Thunder",   icon: "🌩" }
        if (distMi > 5)                      return { title: "Storm Nearby",      icon: "⛈" }
        return                                       { title: "Unplug the Rig!",  icon: "🔌" }
    }

    // Returns {title, icon} based on daily rain total (in)
    function rain(dailyIn) {
        if (dailyIn === undefined || isNaN(dailyIn) || dailyIn === 0)
                                             return { title: "Dry as a Bone",    icon: "🦴" }
        if (dailyIn < 0.1)                   return { title: "Sprinkles",        icon: "💧" }
        if (dailyIn < 1)                     return { title: "Rainy",            icon: "🌧" }
        if (dailyIn < 3)                     return { title: "Soaked",           icon: "☔" }
        return                                       { title: "Biblical",        icon: "🌊" }
    }

    // Returns {title, icon} based on humidity %
    function humidity(h) {
        if (h === undefined || isNaN(h)) return { title: "Humidity", icon: "💦" }
        if (h < 30)                      return { title: "Desert",   icon: "🌵" }
        if (h < 40)                      return { title: "Dry",      icon: "🏜" }
        if (h <= 60)                     return { title: "Comfy",    icon: "😌" }
        if (h <= 80)                     return { title: "Sticky",   icon: "😓" }
        return                                   { title: "Swamp",    icon: "🐊" }
    }

    // UV index
    function uv(v) {
        if (v === undefined || isNaN(v)) return { title: "UV Index",      icon: "☀" }
        if (v < 3)                       return { title: "Vampire Hours", icon: "🧛" }
        if (v < 6)                       return { title: "Hat Weather",   icon: "🧢" }
        if (v < 8)                       return { title: "SPF Time",      icon: "🧴" }
        if (v < 11)                      return { title: "Crispy",        icon: "🔥" }
        return                                   { title: "Face Melter",   icon: "☀" }
    }

    // Solar radiation — W/m² (typical sunny-day noon is ~1000 W/m²)
    function solar(wm2) {
        if (wm2 === undefined || isNaN(wm2)) return { title: "Solar",      icon: "🌤" }
        if (wm2 < 1)                         return { title: "Night Owl",  icon: "🦉" }
        if (wm2 < 50)                        return { title: "Dim",        icon: "🌫" }
        if (wm2 < 400)                       return { title: "Bright",     icon: "🌤" }
        if (wm2 < 900)                       return { title: "Blazing",    icon: "☀" }
        return                                       { title: "Supernova",  icon: "🌟" }
    }

    // Pressure trend (inHg/hr) — positive rising, negative falling
    function pressure(trendPerHr) {
        if (trendPerHr === undefined || isNaN(trendPerHr))
                                             return { title: "Pressure",      icon: "⚖" }
        if (trendPerHr <= -0.04)             return { title: "Storm Brewing", icon: "⛈" }
        if (trendPerHr <= -0.01)             return { title: "Falling",       icon: "📉" }
        if (trendPerHr >=  0.04)             return { title: "Rising Fast",   icon: "📈" }
        if (trendPerHr >=  0.01)             return { title: "Rising",        icon: "📈" }
        return                                       { title: "Steady",       icon: "⚖"  }
    }

    // HF propagation by SFI
    function hfProp(sfi) {
        if (sfi === undefined || isNaN(sfi)) return { title: "HF Propagation",        icon: "📡" }
        if (sfi < 70)                        return { title: "Band Dead",             icon: "💀" }
        if (sfi < 100)                       return { title: "Quiet Bands",           icon: "📻" }
        if (sfi < 150)                       return { title: "Solar / Band Conditions", icon: "📡" }
        return                                       { title: "DX Paradise",          icon: "🌍" }
    }

    // NOAA geomagnetic storm scale from K-index.
    // G0 = quiet, G5 = extreme. Returns {level, title, color}.
    function geoStorm(kidx) {
        if (kidx === undefined || isNaN(kidx)) return { level: "—",  title: "Unknown",   severity: 0 }
        if (kidx < 5)   return { level: "G0", title: "Quiet",       severity: 0 }
        if (kidx < 6)   return { level: "G1", title: "Minor",       severity: 1 }
        if (kidx < 7)   return { level: "G2", title: "Moderate",    severity: 2 }
        if (kidx < 8)   return { level: "G3", title: "Strong",      severity: 3 }
        if (kidx < 9)   return { level: "G4", title: "Severe",      severity: 4 }
        return               { level: "G5", title: "Extreme",     severity: 5 }
    }
}
