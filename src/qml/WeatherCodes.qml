pragma Singleton
import QtQuick

// WMO weather codes used by Open-Meteo.
QtObject {
    function icon(code, isDay) {
        var day = isDay === undefined ? true : isDay
        if (code === undefined || code === null) return "❓"
        if (code === 0)    return day ? "☀"  : "🌙"
        if (code <= 2)     return day ? "🌤" : "☁"
        if (code === 3)    return "☁"
        if (code === 45 || code === 48) return "🌫"
        if (code >= 51 && code <= 57)   return "🌦"
        if (code >= 61 && code <= 67)   return "🌧"
        if (code >= 71 && code <= 77)   return "🌨"
        if (code >= 80 && code <= 82)   return "🌦"
        if (code === 85 || code === 86) return "🌨"
        if (code === 95)                return "⛈"
        if (code >= 96 && code <= 99)   return "⛈"
        return "☁"
    }

    function label(code) {
        if (code === undefined || code === null) return "Unknown"
        if (code === 0)    return "Clear"
        if (code === 1)    return "Mainly clear"
        if (code === 2)    return "Partly cloudy"
        if (code === 3)    return "Overcast"
        if (code === 45)   return "Fog"
        if (code === 48)   return "Freezing fog"
        if (code >= 51 && code <= 57) return "Drizzle"
        if (code >= 61 && code <= 67) return "Rain"
        if (code >= 71 && code <= 77) return "Snow"
        if (code >= 80 && code <= 82) return "Showers"
        if (code === 85 || code === 86) return "Snow showers"
        if (code === 95) return "Thunderstorm"
        if (code >= 96)  return "Thunder + hail"
        return "Unknown"
    }
}
