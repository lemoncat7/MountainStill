@echo off
rem Exit any running MountainStill first. This requests OpenGL for this launch only.
start "" "%~dp0MountainStill.exe" --rendering-driver opengl3
