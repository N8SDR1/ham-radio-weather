import QtQuick
import QtQuick.Layouts
import "../" as App

// Instantiates the correct tile component for a given tileId
// and forwards control signals up to Main.qml.
Loader {
    id: loader

    property string tileId: ""
    property string tileSize: "M"
    property var weatherData: ({})
    property var hfData: ({})
    property var forecastData: ({})
    property var satelliteData: ({})
    property var spaceWxData: ({})
    property int  gridColumnCount: 1

    signal hideRequested(string tileId)
    signal sizeRequested(string tileId, string newSize)
    signal dragStarted(string tileId)
    signal dragEnded(string tileId)
    signal droppedHere(string targetId, bool insertBefore)

    // span capped to current grid columns so XL doesn't explode on narrow windows
    Layout.columnSpan: Math.min(gridColumnCount,
                                App.TileCatalog.columnSpanFor(tileSize))
    Layout.fillWidth: true
    Layout.minimumHeight: App.TileCatalog.minHeightFor(tileSize)

    sourceComponent: {
        switch (tileId) {
            case "outdoor":   return cOutdoor
            case "wind":      return cWind
            case "lightning": return cLightning
            case "rain":      return cRain
            case "shack":     return cShack
            case "humidity":  return cHumidity
            case "uv":        return cUv
            case "solar":     return cSolar
            case "pressure":  return cPressure
            case "hfprop":    return cHfProp
            case "forecast":  return cForecast
            case "sunmoon":   return cSunMoon
            case "satellites":return cSatellites
            case "alerts":    return cAlerts
            case "airquality":return cAirQuality
            case "soil":      return cSoil
            case "leak":      return cLeak
            case "nwsalerts": return cNwsAlerts
            case "spacewx":   return cSpaceWx
        }
        return null
    }

    function _applyData() {
        if (!item) return
        var meta = App.TileCatalog.get(loader.tileId)
        if (!meta) return
        if (meta.source === "hf")            item.data = loader.hfData
        else if (meta.source === "forecast") item.data = loader.forecastData
        else if (meta.source === "sat")      item.data = loader.satelliteData
        else if (meta.source === "spacewx")  item.data = loader.spaceWxData
        else                                 item.data = loader.weatherData
    }

    onLoaded: {
        if (!item) return
        item.tileId   = loader.tileId
        item.tileSize = loader.tileSize
        var meta = App.TileCatalog.get(loader.tileId)
        if (meta && item.hasOwnProperty("minSize"))
            item.minSize = meta.minSize || "S"
        _applyData()
        item.hideRequested.connect(function()   { loader.hideRequested(loader.tileId) })
        item.sizeRequested.connect(function(sz) { loader.sizeRequested(loader.tileId, sz) })
        item.dragStarted.connect(function()         { loader.dragStarted(loader.tileId) })
        item.dragEnded.connect(function()           { loader.dragEnded(loader.tileId) })
        item.droppedHere.connect(function(before)   { loader.droppedHere(loader.tileId, before) })
    }

    onWeatherDataChanged:   _applyData()
    onHfDataChanged:        _applyData()
    onForecastDataChanged:  _applyData()
    onSatelliteDataChanged: _applyData()
    onSpaceWxDataChanged:   _applyData()
    onTileSizeChanged:      if (item) item.tileSize = tileSize

    Component { id: cOutdoor;   CurrentConditionsTile {} }
    Component { id: cWind;      WindTile {} }
    Component { id: cLightning; LightningTile {} }
    Component { id: cRain;      RainTile {} }
    Component { id: cShack;     ShackOrHellTile {} }
    Component { id: cHumidity;  HumidityTile {} }
    Component { id: cUv;        UVTile {} }
    Component { id: cSolar;     SolarTile {} }
    Component { id: cPressure;  PressureTile {} }
    Component { id: cHfProp;    HFPropagationTile {} }
    Component { id: cForecast;   ForecastTile {} }
    Component { id: cSunMoon;    SunMoonTile {} }
    Component { id: cSatellites; SatelliteTile {} }
    Component { id: cAlerts;     AlertsTile {} }
    Component { id: cAirQuality; AirQualityTile {} }
    Component { id: cSoil;       SoilTile {} }
    Component { id: cLeak;       LeakTile {} }
    Component { id: cNwsAlerts;  NwsAlertsTile {} }
    Component { id: cSpaceWx;    SpaceWeatherTile {} }
}
