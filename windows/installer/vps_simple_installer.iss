; Inno Setup-скрипт для Windows-установщика VPS Simple.
; Папка с собранным приложением передаётся через ISCC:
;   ISCC /DMyAppSrc="path\to\build\windows\x64\runner\Release" vps_simple_installer.iss
; Версию можно переопределить: /DMyAppVersion=0.2.0

#define MyAppName "VPS Simple"
#ifndef MyAppVersion
  #define MyAppVersion "0.2.0"
#endif
#define MyAppPublisher "villcreat & GEFSED"
#define MyAppExeName "vps_simple.exe"
#ifndef MyAppSrc
  #define MyAppSrc "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{B4F2B9C2-7E2A-4E7D-9B7A-1C3D5E7F9A2B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\VPS Simple
DefaultGroupName=VPS Simple
DisableProgramGroupPage=yes
OutputDir=installer_output
OutputBaseFilename=VPS-Simple-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppSrc}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\VPS Simple"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,VPS Simple}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\VPS Simple"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,VPS Simple}"; Flags: nowait postinstall skipifsilent
