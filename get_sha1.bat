@echo off
echo ===== SHA-1 Fingerprint Generator =====
echo.

keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android > sha1_output.txt
echo SHA-1 fingerprint exported to sha1_output.txt in the current directory
echo Please open this file and look for the SHA-1 fingerprint line
