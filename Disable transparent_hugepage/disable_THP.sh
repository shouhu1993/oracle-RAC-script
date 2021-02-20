#!/bin/bash
# Disable transparent_hugepage
# get the option from /sys/kernel/mm/transparent_hugepage/enabled, the THP is the current option of the transparent_hugepage. 
THP=$(awk '{for(i=1;i<=NF;i++){if($i ~ /\[([a-z]*)\]/){print $i;break;}}}' /sys/kernel/mm/transparent_hugepage/enabled)
echo $THP
if [ "$THP" != "[never]" ];then
	CURRENT_TUNE_PROFILE=$(tuned-adm active | awk '{print $4}')
	echo -e '[vm]\ntransparent_hugepages=never' >> /usr/lib/tuned/$CURRENT_TUNE_PROFILE/tuned.conf
	tuned-adm profile $CURRENT_TUNE_PROFILE
	tuned-adm active
	cat /sys/kernel/mm/transparent_hugepage/enabled
else
	echo "transparent_hugepage is already disabled"
fi

