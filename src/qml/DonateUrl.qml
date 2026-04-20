pragma Singleton
import QtQuick

// Single source of truth for the PayPal donate URL so header button, About
// dialog, and the 7th-launch nudge all stay in sync.
QtObject {
    readonly property string url:
          "https://www.paypal.com/donate/?business=NP2ZQS4LR454L"
        + "&no_recurring=0"
        + "&item_name=Built+by+a+fellow+ham%2C+for+the+community.++Free+to+use%2C"
        + "+free+to+share.+A+small+donation+keeps+the+code+flowing.+73+de+N8SDR"
        + "&currency_code=USD"
}
