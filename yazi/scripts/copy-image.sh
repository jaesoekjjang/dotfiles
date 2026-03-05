#!/bin/bash
osascript -e 'tell app "Finder" to set the clipboard to (POSIX file "'"$1"'")'
