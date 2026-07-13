@echo off
pushd "%~dp0"
call "%ProgramFiles%\nodejs\npm.cmd" test
set "test_exit=%errorlevel%"
popd
exit /b %test_exit%
