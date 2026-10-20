#!/bin/bash
# Checks the ROM zips in ../roms against ../roms/ROM-MANIFEST.txt.
# Uses unzip -v, which prints each entry's uncompressed size and CRC32 without extracting.
# Exit: 0 all good, 1 at least one mismatch, 2 no ROMs present.
cd "$(dirname "$0")" || exit 2
ROMS="../roms"; MAN="../roms/ROM-MANIFEST.txt"
[ -f "$MAN" ] || { echo "  ROM-MANIFEST.txt missing - skipping check."; exit 0; }

present=0; good=0; problems=()
zips=$(grep -v '^[[:space:]]*#' "$MAN" | grep '|' | cut -d'|' -f1 | sort -u)

for z in $zips; do
  [ -f "$ROMS/$z" ] || continue
  present=$((present+1))

  # actual contents: "name size crc"
  actual=$(unzip -v "$ROMS/$z" 2>/dev/null | awk 'NR>3 && NF>=8 && $8!="" {
      crc=tolower($7); name=$8; for(i=9;i<=NF;i++) name=name" "$i;
      print name" "$1" "crc }' | sed 's/[[:space:]]*$//')

  missing=(); wrong=()
  while IFS='|' read -r mz mf msize mcrc; do
    [ "$mz" = "$z" ] || continue
    line=$(printf '%s\n' "$actual" | grep -F "$mf " | head -1)
    if [ -z "$line" ]; then
      missing+=("$mf")
    else
      asize=$(printf '%s' "$line" | awk '{print $(NF-1)}')
      acrc=$(printf '%s' "$line" | awk '{print $NF}')
      if [ "$asize" != "$msize" ] || [ "$acrc" != "$mcrc" ]; then wrong+=("$mf"); fi
    fi
  done < <(grep -v '^[[:space:]]*#' "$MAN" | grep "^$z|")

  if [ ${#missing[@]} -eq 0 ] && [ ${#wrong[@]} -eq 0 ]; then
    echo "  OK       $z"; good=$((good+1))
  else
    echo "  MISMATCH $z"
    [ ${#missing[@]} -gt 0 ] && problems+=("  $z: ${#missing[@]} file(s) missing, e.g. ${missing[*]:0:3}")
    [ ${#wrong[@]}   -gt 0 ] && problems+=("  $z: ${#wrong[@]} file(s) wrong version, e.g. ${wrong[*]:0:3}")
  fi
done

echo
if [ "$present" -eq 0 ]; then
  echo "  No ROM zips found in the roms folder."
  echo "  See roms/PUT-YOUR-ROMS-HERE.txt for the exact filenames needed."
  exit 2
fi
echo "  $good of $present set(s) present matched the known-good versions."
if [ ${#problems[@]} -gt 0 ]; then
  echo; echo "  Problems found:"
  printf '%s\n' "${problems[@]}"
  echo
  echo "  A mismatched set usually means a different region or a newer/older"
  echo "  dump than the cores expect. Sets marked OK are the tested ones."
  exit 1
fi
exit 0
