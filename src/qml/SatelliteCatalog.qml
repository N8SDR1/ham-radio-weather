pragma Singleton
import QtQuick

// Curated list — every entry corresponds to a BLUE-checked satellite in the
// user's CSN Technologies S.A.T. reference. Dead / uncertain birds are
// removed entirely (PO-101, TEVEL 1-8, AO-109, HO-113, MESAT1, CAS-4A/B,
// NEXUS, TO-108). Revisit this list when CSN updates their reference.
//
// Celestrak amateur-TLE group names are matched via SatellitesClient's fuzzy
// lookup with word-boundary matching.
QtObject {
    readonly property var catalog: [
        { id: "ISS (ZARYA)",  label: "ISS — Int'l Space Station (FM voice/packet)", defaultEnabled: true },
        { id: "AO-7",         label: "AO-7 (AMSAT-OSCAR 7, oldest still-operational!)", defaultEnabled: true },
        { id: "AO-27",        label: "AO-27 (EYESAT-1, FM)",                       defaultEnabled: true },
        { id: "AO-73",        label: "AO-73 (FUNcube-1, linear + telemetry)",      defaultEnabled: true },
        { id: "AO-123",       label: "AO-123 (CATSat, linear)",                    defaultEnabled: true },
        { id: "FO-29",        label: "FO-29 (Fuji-OSCAR 29 / JAS-2)",              defaultEnabled: true },
        { id: "SO-50",        label: "SO-50 (SaudiSat-1C, FM)",                    defaultEnabled: true },
        { id: "RS-44",        label: "RS-44 (DOSAAF-85, linear)",                  defaultEnabled: true },
        { id: "HADES-ICM",    label: "HADES-ICM (SO-125)",                         defaultEnabled: true },
        { id: "HADES-SA",     label: "HADES-SA",                                   defaultEnabled: true },
        { id: "IO-86",        label: "IO-86 (LAPAN-A2, Indonesian FM)",            defaultEnabled: true },
        { id: "JO-97",        label: "JO-97 (JAISAT-1, JAMSAT/Japanese)",          defaultEnabled: true },
        { id: "NANOZOND-1",   label: "RS49S NANOZOND-1 (Russian CubeSat)",         defaultEnabled: true }
    ]

    function defaultEnabledIds() {
        return catalog.filter(function(s) { return s.defaultEnabled })
                      .map(function(s) { return s.id })
    }
}
