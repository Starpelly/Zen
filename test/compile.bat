@echo off
del Player.exe

"../build/Debug_Win64/Zen/Zen.exe" ^
src/Player.zen ^
output/src

"./tcc/tcc.exe" ^
output/src/Player.c ^
-g ^
-w ^
-o output/build/Player.exe

ECHO ==============================

"./output/build/Player.exe"