@echo off
setlocal

echo ========================================
echo Risha automated verification suite
echo ========================================

echo.
echo [1/3] Installing Flutter dependencies...
call flutter pub get
if errorlevel 1 goto failed

echo.
echo [2/3] Running static analysis...
call flutter analyze
if errorlevel 1 goto failed

echo.
echo [3/3] Running automated tests...
call flutter test test\master_test_runner.dart
if errorlevel 1 goto failed

echo.
echo ========================================
echo All Risha checks passed successfully.
echo ========================================
exit /b 0

:failed
echo.
echo ========================================
echo Risha checks failed. Review the output above.
echo ========================================
exit /b 1
