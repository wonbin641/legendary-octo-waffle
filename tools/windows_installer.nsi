; 야르 07 (Godot판) Windows 설치 파일. tools/build_windows.sh 가 만듭니다: makensis -DOUTDIR=... -DVERSION=... tools/windows_installer.nsi
; 관리자 권한 없이 사용자 폴더(%LOCALAPPDATA%\Programs\Yarr07)에 설치하고, 시작 메뉴·바탕 화면 바로 가기와 제거 프로그램을 둡니다.
; 저장 기록(%APPDATA%\Godot\app_userdata\Yarr! 07)은 제거해도 남습니다.
Target amd64-unicode   ; (the game is 64-bit; so is the installer, and it installs where 64-bit programs go)
SetCompressor /SOLID lzma
!include "MUI2.nsh"

!define APP "야르 07"
!define KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Yarr07"
Name "${APP}"
OutFile "${OUTDIR}\Yarr07-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Yarr07"
InstallDirRegKey HKCU "${KEY}" "InstallLocation"
RequestExecutionLevel user
BrandingText "${APP} ${VERSION}"
VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=1042 "ProductName" "${APP}"
VIAddVersionKey /LANG=1042 "FileDescription" "${APP} 설치"
VIAddVersionKey /LANG=1042 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=1042 "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=1042 "LegalCopyright" ""

!define MUI_ICON "${OUTDIR}\icon.ico"
!define MUI_UNICON "${OUTDIR}\icon.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\Yarr07.exe"
!define MUI_FINISHPAGE_RUN_TEXT "지금 ${APP} 시작"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Korean"

Section "Install"
  SetOutPath "$INSTDIR"
  File "${OUTDIR}\Yarr07.exe"
  File "/oname=icon.ico" "${OUTDIR}\icon.ico"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$SMPROGRAMS\${APP}.lnk" "$INSTDIR\Yarr07.exe" "" "$INSTDIR\icon.ico"
  CreateShortcut "$DESKTOP\${APP}.lnk" "$INSTDIR\Yarr07.exe" "" "$INSTDIR\icon.ico"
  WriteRegStr HKCU "${KEY}" "DisplayName" "${APP}"
  WriteRegStr HKCU "${KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${KEY}" "DisplayIcon" "$INSTDIR\icon.ico"
  WriteRegStr HKCU "${KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "${KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${KEY}" "NoRepair" 1
  WriteRegDWORD HKCU "${KEY}" "EstimatedSize" ${SIZE_KB}
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\Yarr07.exe"
  Delete "$INSTDIR\icon.ico"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APP}.lnk"
  Delete "$DESKTOP\${APP}.lnk"
  DeleteRegKey HKCU "${KEY}"
SectionEnd
