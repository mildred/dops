files=
for f in *.sh.in; do
  files="$files ${f%.in}"
done
redo-ifchange $files
