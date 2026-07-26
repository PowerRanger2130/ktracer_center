!include "LogicLib.nsh"
OutFile "KTracerCenterSetup.exe"
InstallDir "$LOCALAPPDATA\\KTracerCenter"
RequestExecutionLevel user

Section "Install"
  ; Close running app if open
  nsExec::ExecToStack 'taskkill /IM ktracer_center.exe /F'
  Sleep 1000

  ; Create install directory
  CreateDirectory "$INSTDIR"

  ; Copy all files from your build output
  SetOutPath "$INSTDIR"
  File /r "..\\build\\windows\\x64\\runner\\Release\\*.*"

  ; Create shortcut on Desktop
  CreateShortCut "$DESKTOP\\KTracer Center.lnk" "$INSTDIR\\ktracer_center.exe"

  WriteUninstaller "$INSTDIR\\Uninstall.exe"

  HideWindow
  Exec "$INSTDIR\\ktracer_center.exe"
SectionEnd

Section "Uninstall"
  ; Remove shortcut
  Delete "$DESKTOP\\KTracer Center.lnk"
  ; Remove all files
  RMDir /r "$INSTDIR"
SectionEnd