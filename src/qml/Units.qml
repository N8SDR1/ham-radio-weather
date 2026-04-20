pragma Singleton
import QtQuick

QtObject {
    id: units

    // "imperial" | "metric"
    property string system: "imperial"
    readonly property bool metric: system === "metric"

    function tempF(v)   { return metric ? ((v - 32) * 5/9) : v }
    function tempUnit() { return metric ? "°C" : "°F" }

    function windMph(v)   { return metric ? v * 1.609344 : v }
    function windUnit()   { return metric ? "km/h" : "mph" }

    function rainIn(v)    { return metric ? v * 25.4 : v }
    function rainUnit()   { return metric ? "mm" : "in" }

    function distMi(v)    { return metric ? v * 1.609344 : v }
    function distUnit()   { return metric ? "km" : "mi" }

    function presIn(v)    { return metric ? v * 33.8639 : v }
    function presUnit()   { return metric ? "hPa" : "inHg" }

    function fmt(v, digits) {
        if (v === undefined || v === null || isNaN(v)) return "—"
        return Number(v).toFixed(digits === undefined ? 1 : digits)
    }
}
