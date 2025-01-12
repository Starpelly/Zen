@echo off

"../build/Debug_Win64/Zen/Zen.exe" ^
src ^
build/codegen

if ERRORLEVEL 1 exit

"./tcc/tcc.exe" ^
build/codegen/Program.c ^
build/codegen/Program/Main.c ^
build/codegen/Program/Print.c ^
build/codegen/Program/Math.c ^
-g ^
-w ^
-o build/bin/Main.exe

if ERRORLEVEL 1 exit

ECHO ===============================

"./build/bin/Main.exe"