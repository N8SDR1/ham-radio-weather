pragma Singleton
import QtQuick

// Single source of truth for every tile the dashboard knows about.
// Adding a new tile: append an entry here, create the QML file, and add the
// case branch in TileLoader.qml.
QtObject {
    readonly property var tiles: [
        { id: "outdoor",   name: "Outdoor",         defaultSize: "L", minSize: "M", source: "weather"  },
        { id: "wind",      name: "Wind",            defaultSize: "M", minSize: "M", source: "weather"  },
        { id: "lightning", name: "Lightning",       defaultSize: "M", minSize: "M", source: "weather"  },
        { id: "rain",      name: "Rain Fall",       defaultSize: "M", minSize: "M", source: "weather"  },
        { id: "shack",     name: "Shack or Hell",   defaultSize: "M", minSize: "M", source: "weather", requiresLocalStation: true },
        { id: "humidity",  name: "Humidity",        defaultSize: "S", minSize: "S", source: "weather"  },
        { id: "uv",        name: "UV Index",        defaultSize: "S", minSize: "S", source: "weather"  },
        { id: "solar",     name: "Solar Radiation", defaultSize: "M", minSize: "S", source: "weather"  },
        { id: "pressure",  name: "Pressure",        defaultSize: "M", minSize: "M", source: "weather"  },
        { id: "hfprop",    name: "HF Propagation",  defaultSize: "L", minSize: "L", source: "hf"       },
        { id: "forecast",  name: "Forecast",        defaultSize: "L", minSize: "L", source: "forecast" },
        { id: "sunmoon",   name: "Sun / Moon",      defaultSize: "M", minSize: "M", source: "forecast" },
        { id: "satellites", name: "Satellites",     defaultSize: "L", minSize: "M", source: "sat"      },
        { id: "alerts",     name: "Alerts",         defaultSize: "M", minSize: "M", source: "weather"  },
        { id: "airquality", name: "Air Quality",    defaultSize: "M", minSize: "M", source: "weather", defaultHidden: true },
        { id: "soil",       name: "Soil Probes",    defaultSize: "M", minSize: "M", source: "weather", defaultHidden: true },
        { id: "leak",       name: "Leak Detectors", defaultSize: "M", minSize: "M", source: "weather", defaultHidden: true }
    ]

    readonly property var _sizeOrderArr: ["S", "M", "L", "XL"]

    function defaultOrder() {
        return tiles.map(function(t) { return t.id })
    }

    function defaultHiddenIds() {
        return tiles.filter(function(t) { return t.defaultHidden === true })
                    .map(function(t) { return t.id })
    }

    function get(id) {
        for (var i = 0; i < tiles.length; i++)
            if (tiles[i].id === id) return tiles[i]
        return null
    }

    function sizeOrder(size) {
        var i = _sizeOrderArr.indexOf(size)
        return i < 0 ? 1 : i
    }

    function clampSize(id, size) {
        var meta = get(id)
        if (!meta) return size
        var min = meta.minSize || "S"
        return sizeOrder(size) < sizeOrder(min) ? min : size
    }

    function allowedSizes(id) {
        var meta = get(id)
        var minIdx = meta ? sizeOrder(meta.minSize || "S") : 0
        return _sizeOrderArr.slice(minIdx)
    }

    // Keep tile heights uniform so rows align; size only affects width.
    readonly property int tileHeight: 300
    function minHeightFor(size) { return tileHeight }

    function columnSpanFor(size) {
        if (size === "S") return 1
        if (size === "M") return 1
        if (size === "L") return 2
        if (size === "XL") return 3
        return 1
    }
}
