@echo off
:: Created by Nils Herde 2013.12.11
:: Creates a tree listing of "source" in txt format
:: Requires GNUWin32 Tree for Windows http://gnuwin32.sourceforge.net/packages/tree.htm

title Filesystem snapshot
set exec="C:\Program Files (x86)\GnuWin32\bin\tree.exe"
set timestamp=%date:~6,4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%

:: Root of the snapshot
set source=D:
:: Destination of snapshot
set dest="D:\Arkiv\backup-logger\%timestamp%_filesystem-snapshot.txt"

:: program
echo Creating snapshot ...
%source%
%exec% -o %dest%

exit