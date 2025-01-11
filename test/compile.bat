@echo off

"../build/Debug_Win64/Zen/Zen.exe" ^
src ^
output/src

"./tcc/tcc.exe" ^
output/src/Program/Main.c ^
-g ^
-w ^
-o output/build/Main.exe

ECHO ==============================

"./output/build/Main.exe"