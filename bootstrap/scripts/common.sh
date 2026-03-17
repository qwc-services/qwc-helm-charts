#!/usr/bin/env bash
# shellcheck disable=SC2086

function logInfo() {
	echo -e -n "$(date +'%Y-%m-%d %H:%M:%S') ======================== "
	echo -e -n "$1: "
	echo "$2"
}

function failed() {
	if [ -z "$1" ]; then
		echo 'Premature end of process: FAILURE!'
	else
		echo "Premature end of process: $*"
	fi

	exit 1
}

function parse_mustache() {
	for f in "$@"; do
		[ -z "$f" ] || [ ! -f "$f" ] && failed "Unable to parse file '$f': file not found!"

		[[ "$f" =~ .*~$ ]] || sed 's/\$/sdDolLaRSigNe/g;s/{{\([A-Za-z0-9_]*\)}}/${\1}/g' "$f" |
			envsubst |
			sed 's/sdDolLaRSigNe/$/g'
	done
}

# for each sample file, replace {{ ENV_VAR }} by env var value
# first parameter is the directory to parse files
# second parameter is file type to parse
function parse_inplace() {
	# shellcheck disable=SC2044
	for f in $(find "$1" -type f -iname "$2"); do
		parse_mustache $f >$f.tmp || failed "Unable to parse_mustache '$f'"
		mv $f.tmp $f || failed "Unable to rename tmp file '$f'"
	done
}

function configmap_to_files() {
	[ -z "$1" ] && failed "Need first param: SRC"
	SRC="$1"
	[ -z "$2" ] && failed "Need first param: DEST"
	DEST="$2"
	[ -z "$3" ] && failed "Need first param: WATCHDOG_FILE"
	WATCHDOG_FILE="$3"

	logInfo "Configmap_to_files" "Decompressing ${SRC} to ${DEST}"

	# if no asset are already present we copy the default ones
	if [ -f "$DEST/$WATCHDOG_FILE" ]; then
		echo "Nothing to do!"
	else
		cd "$SRC" || failed "Unable to reach '$SRC'"

		# shellcheck disable=SC2044
		for f in $(find ./ -maxdepth 1 -type l); do
			newpath=$(echo $f | sed 's|--|/|g' | sed 's|^\./||g')
			# skip internal configMap mechanism directory:
			[ "$newpath" == "..data" ] && continue
			echo "Copying $f => $DEST/$newpath"
			mkdir -p "$(dirname $DEST/$newpath)" || failed "Unable to create dir '$DEST/$newpath'"
			base64 -d "$f" >"$DEST/$(dirname $newpath)/$(basename $newpath)"

		done
	fi

	echo "Done!"
}
