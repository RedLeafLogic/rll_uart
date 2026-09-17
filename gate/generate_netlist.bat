@echo off
setlocal
pushd "%~dp0..\syn"

quartus_eda --read_settings_files=on --write_settings_files=off ^
  --simulation=on --functional=on --flatten_buses=off --timescale=1ps ^
  --tool=modelsim --format=verilog --output_directory=..\gate ^
  uart_top -c uart_top
set NETLIST_RC=%ERRORLEVEL%

popd
if not "%NETLIST_RC%"=="0" exit /b %NETLIST_RC%

if not exist "%~dp0uart_top.vo" exit /b 2
exit /b 0
