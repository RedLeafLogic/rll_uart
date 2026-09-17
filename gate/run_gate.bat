@echo off
setlocal
pushd "%~dp0"
vsim -c -do run_functional_gate.do
set SIM_RC=%ERRORLEVEL%
popd
exit /b %SIM_RC%
