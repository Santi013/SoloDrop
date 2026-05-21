#define MyAppName "SoloDrop Server"
#define MyAppVersion "0.3.0"
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
OutputBaseFilename=SoloDropSetup-Windows
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ShowLanguageDialog=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
Source: "dist\SoloDropServer\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "start_server.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "Start SoloDrop Hidden.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "SoloDrop Tray.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Stop SoloDrop.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "config.example.json"; DestDir: "{app}"; DestName: "config.json"; Flags: onlyifdoesntexist ignoreversion

[Dirs]
Name: "{app}\data"
Name: "{app}\data\uploads"
Name: "{app}\data\previews"
Name: "{app}\certs"
Name: "{app}\logs"

[Icons]
Name: "{autoprograms}\SoloDrop"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Start SoloDrop Hidden.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\static\icons\tray-icon.ico"
Name: "{autodesktop}\SoloDrop"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Start SoloDrop Hidden.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\static\icons\tray-icon.ico"; Tasks: desktopicon
Name: "{userstartup}\SoloDrop"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Start SoloDrop Hidden.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\static\icons\tray-icon.ico"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: checkedonce

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\Start SoloDrop Hidden.vbs"""; Description: "Launch SoloDrop"; Flags: postinstall nowait skipifsilent
Filename: "http://127.0.0.1:8000"; Description: "Open SoloDrop"; Flags: shellexec postinstall nowait skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\logs\*.log"

[UninstallRun]
Filename: "{app}\Stop SoloDrop.cmd"; Parameters: "--quiet"; Flags: runhidden; RunOnceId: "StopSoloDropServer"
