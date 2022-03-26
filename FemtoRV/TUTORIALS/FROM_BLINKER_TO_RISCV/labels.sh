./run.sh $1 -DGET_ASM_LABELS | grep 'Label:' | sed -e 's|Label:|=|g' -e 's|$|;|g'  > values.txt
cat $1 | grep 'Label(' | sed -e 's|Label(|integer |g' -e 's|)||g' -e's|;||g' > labels.txt
paste labels.txt values.txt
rm -f labels.txt values.txt
