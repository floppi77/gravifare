#!/usr/bin/env bash
# rec_one.sh <name> <lang> <level|res://szene> <frames> <hud 0|1> <fuel|-> [extra]
SP=${GF_REC_SP:?Ordner mit der Aufnahmekopie unter rec/ (siehe README)}
CL=${GF_TRAILER_CLIPS:-$HOME/.cache/gravifare-trailer/clips_v3}
mkdir -p "$CL" "$SP/rec_logs"
name=$1; lang=$2; lvl=$3; frames=$4; hud=$5; fuel=$6; extra=${7:-}
if [[ "$lvl" == res://* ]]; then scene=$lvl; args="--lang=$lang"; else scene=""; args="--lang=$lang --level=$lvl --autopilot --seed=1 --trace=$CL/$name.trace $extra"; fi
[ "$hud" = "0" ] && args="$args --no-hud"
[ "$fuel" != "-" ] && export GF_FUEL=$fuel
X=$(mktemp -d -p $SP xdgrec.XXXX); mkdir -p $X/data $X/config $X/cache
export XDG_DATA_HOME=$X/data XDG_CONFIG_HOME=$X/config XDG_CACHE_HOME=$X/cache
cd $SP/rec && timeout 900 gamescope --backend headless -W 1920 -H 1080 -w 1920 -h 1080 -- godot --path . -w --resolution 1920x1080 --write-movie $CL/$name.avi --fixed-fps 60 --quit-after $frames $scene -- $args > $SP/rec_logs/$name.log 2>&1
rm -rf $X
echo "$name fertig $(ls -la $CL/$name.avi 2>/dev/null | awk '{print $5}')"
