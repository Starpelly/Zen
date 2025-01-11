@echo off

"../build/Debug_Win64/Zen/Zen.exe" ^
src ^
output/src

"./tcc/tcc.exe" ^
output/src/Program.c ^
output/src/Program/Main.c ^
output/src/Program/Player.c ^
output/src/Program/Math.c ^
-g ^
-w ^
-o output/build/Main.exe

ECHO ==============================

"./output/build/Main.exe"