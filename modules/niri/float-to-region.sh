#!/usr/bin/env bash

# Define left/top edge offset (accounts for waybar + gaps/structs)
X_OFFSET=0
Y_OFFSET=0

# Bail if no window is currently focused
IS_FLOATING=$(niri msg -j focused-window | jq .is_floating)
if [ "$IS_FLOATING" == "null" ]; then 
	echo "No focused window!"
    exit
fi

# Handle special 'read offsets' case when script is called with -o flag
if [ "$1" = "-o" ]; then

	# Force window to (0,0) and read actual position to figure out the offset
	if ! $IS_FLOATING; then	niri msg action move-window-to-floating; fi
	niri msg action move-floating-window -x 0 -y 0
	ZEROED_WIN_LAYOUT=$(niri msg -j focused-window | jq .layout)
	ACTUAL_X_0=$(jq .tile_pos_in_workspace_view[0] <<< $ZEROED_WIN_LAYOUT)
	ACTUAL_Y_0=$(jq .tile_pos_in_workspace_view[1] <<< $ZEROED_WIN_LAYOUT)
	
	# Report (as integers)
	ACTUAL_X_0=${ACTUAL_X_0%.*}
	ACTUAL_Y_0=${ACTUAL_Y_0%.*}
	echo "X_OFFSET=$ACTUAL_X_0"
	echo "Y_OFFSET=$ACTUAL_Y_0"
	exit
fi

# Get box selection (or bail if canceled)
BOX_INFO=$(slurp -d -f '{"x":%x,"y":%y,"w":%w,"h":%h}') || exit
BOX_X=$(jq .x <<< $BOX_INFO)
BOX_Y=$(jq .y <<< $BOX_INFO)
BOX_W=$(jq .w <<< $BOX_INFO)
BOX_H=$(jq .h <<< $BOX_INFO)

# Compute offset x/y location (using integers!)
X_OFFSET_INT=${X_OFFSET%.*}
Y_OFFSET_INT=${Y_OFFSET%.*}
BOX_X_CORRECTED=$(($BOX_X - $X_OFFSET_INT))
BOX_Y_CORRECTED=$(($BOX_Y - $Y_OFFSET_INT))

# Force window to float and resize/move to slurp location
if ! $IS_FLOATING; then niri msg action move-window-to-floating; fi
niri msg action set-window-width $BOX_W
niri msg action set-window-height $BOX_H
niri msg action move-floating-window -x $BOX_X_CORRECTED -y $BOX_Y_CORRECTED
