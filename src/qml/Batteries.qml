pragma Singleton
import QtQuick

// Interprets the `batt*` fields Ambient stations publish.
// Convention: 1 = OK (good), 0 = low. A few older models invert — if you hit
// one, add its keys here and flip the `ok` logic.
QtObject {
    function detect(data) {
        var result = { hasAny: false, allOk: true, lowList: [], items: [] }
        if (!data) return result
        for (var k in data) {
            if (!k || k.indexOf("batt") !== 0) continue
            var v = data[k]
            if (v === undefined || v === null) continue
            var n = Number(v)
            if (isNaN(n)) continue
            result.hasAny = true
            var ok = n !== 0
            result.items.push({ key: k, value: n, ok: ok })
            if (!ok) {
                result.allOk = false
                result.lowList.push(k)
            }
        }
        // stable order
        result.items.sort(function(a, b) { return a.key.localeCompare(b.key) })
        return result
    }

    function prettyName(key) {
        var m = {
            "battout":         "Outdoor array",
            "battin":          "Indoor console",
            "batt_co2":        "Indoor air quality (CO₂)",
            "batt_25":         "PM2.5 sensor",
            "batt_25in":       "PM2.5 indoor",
            "batt_lightning":  "Lightning sensor",
            "battrain":        "Rain gauge",
            "batt_cellgateway":"Cell gateway",
            "batt1":  "Sensor 1",  "batt2":  "Sensor 2",
            "batt3":  "Sensor 3",  "batt4":  "Sensor 4",
            "batt5":  "Sensor 5",  "batt6":  "Sensor 6",
            "batt7":  "Sensor 7",  "batt8":  "Sensor 8",
            "batt9":  "Sensor 9",  "batt10": "Sensor 10",
            "batt_leak1": "Leak sensor 1", "batt_leak2": "Leak sensor 2",
            "batt_leak3": "Leak sensor 3", "batt_leak4": "Leak sensor 4",
            "batt_soilmoisture1": "Soil moisture 1",
            "batt_soilmoisture2": "Soil moisture 2"
        }
        return m[key] || key
    }
}
