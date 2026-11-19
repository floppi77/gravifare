#!/usr/bin/env bash
# rec_one.sh <name> <lang> <level|res://szene> <frames> <hud 0|1> <fuel|-> [extra]
SP=${GF_REC_SP:?Ordner mit der Aufnahmekopie unter rec/ (siehe README)}
CL=${GF_TRAILER_CLIPS:-$HOME/.cache/gravifare-trailer/clips_v5}
RW=${GF_REC_W:-3840}; RH=${GF_REC_H:-2160}        # Fassung 5: Aufnahme in 4K (Pixelgröße 6, die größte eigene Grafikstufe)
FPS=${GF_REC_FPS:-60}                              # Zeitlupen-Aufnahmen: 240 (echte Einzelbilder statt Überblendung)
mkdir -p "$CL" "$SP/rec_logs"
name=$1; lang=$2; lvl=$3; frames=$4; hud=$5; fuel=$6; extra=${7:-}
if [[ "$lvl" == res://* ]]; then scene=$lvl; args="--lang=$lang"; else scene=""; args="--lang=$lang --level=$lvl --autopilot --seed=1 --trace=$CL/$name.trace $extra"; fi
[ "$hud" = "0" ] && args="$args --no-hud"
[ "$fuel" != "-" ] && export GF_FUEL=$fuel
X=$(mktemp -d -p $SP xdgrec.XXXX); mkdir -p $X/data $X/config $X/cache
export XDG_DATA_HOME=$X/data XDG_CONFIG_HOME=$X/config XDG_CACHE_HOME=$X/cache
# ohne Einspieler und Tutorial-Hinweise (frischer Spielstand zeigte sonst „Neu: …“ über dem Spiel)
mkdir -p "$X/data/godot/app_userdata/GraviFare" && printf '[settings]\n\nhints=false\n' > "$X/data/godot/app_userdata/GraviFare/settings.cfg"
cd $SP/rec && timeout 900 gamescope --backend headless -W $RW -H $RH -w $RW -h $RH -- godot --path . -w --resolution ${RW}x${RH} --write-movie $CL/$name.avi --fixed-fps $FPS --quit-after $frames $scene -- $args > $SP/rec_logs/$name.log 2>&1
rm -rf $X
echo "$name fertig $(ls -la $CL/$name.avi 2>/dev/null | awk '{print $5}')"
