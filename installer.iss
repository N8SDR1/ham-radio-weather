; Inno Setup script for Ham Radio Weather.
; Build after PyInstaller has produced dist\HamRadioWeather\.

#define MyAppName          "Ham Radio Weather"
#define MyAppShortName     "HamRadioWeather"
#define MyAppVersion       "1.0.8"
#define MyAppPublisher     "N8SDR - Rick Langford"
#define MyAppURL           "https://www.paypal.com/donate/?business=NP2ZQS4LR454L"
#define MyAppExeName       "HamRadioWeather.exe"

[Setup]
; Stable AppId so upgrade installs replace the previous install.
AppId={{D4E4F5A2-7B3C-4E9F-8C1D-9A7B6F5D4E3A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputBaseFilename={#MyAppShortName}-Setup-{#MyAppVersion}
OutputDir=dist\installer

SetupIconFile=assets\icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; \
    GroupDescription: "Additional icons:"

[Files]
Source: "dist\HamRadioWeather\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}";  Filename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch {#MyAppName}"; \
    Flags: nowait postinstall skipifsilent
