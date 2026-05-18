#define MyAppName "SoloDrop Server"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "SoloDrop"
#define MyAppExeName "SoloDropServer.exe"

[Setup]
AppId={{7C5A4D6F-68E5-4B42-9B58-7B6F9AC07F7C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\SoloDrop
DisableProgramGroupPage=yes
OutputDir=installer
OutputBaseFilename=SoloDropSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "dist\SoloDropServer\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "start_server.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "config.example.json"; DestDir: "{app}"; DestName: "config.json"; Flags: onlyifdoesntexist ignoreversion

[Dirs]
Name: "{app}\data"
Name: "{app}\data\uploads"
Name: "{app}\data\previews"
Name: "{app}\certs"
Name: "{app}\logs"

[Icons]
Name: "{autoprograms}\SoloDrop Server"; Filename: "{app}\start_server.bat"; WorkingDir: "{app}"
Name: "{autodesktop}\SoloDrop Server"; Filename: "{app}\start_server.bat"; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: checkedonce

[Run]
Filename: "{app}\start_server.bat"; Description: "Launch SoloDrop Server"; Flags: postinstall nowait skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\logs\*.log"
