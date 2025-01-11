@echo off

"../build/Debug_Win64/Zen/Zen.exe" ^
src ^
output/src

if ERRORLEVEL 1 exit

"./tcc/tcc.exe" ^
output/src/Program.c ^
output/src/Program/Main.c ^
output/src/Program/Print.c ^
output/src/Program/Math.c ^
-g ^
-w ^
-o output/build/Main.exe

if ERRORLEVEL 1 exit

ECHO ===============================

"./output/build/Main.exe"