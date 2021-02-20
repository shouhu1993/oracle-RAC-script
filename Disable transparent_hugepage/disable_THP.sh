#!/bin/bash
# Disable transparent_hugepage
# get the option from /sys/kernel/mm/transparent_hugepage/enabled, the TSHG is the current option of the transparent_hugepage. the oracle's recommend option is never 
TSHG=$(awk '{for(i=1;i<=NF;i++){if($i ~ /\[([a-z]*)\]/){print $i;break;}}}' /sys/kernel/mm/transparent_hugepage/enabled)
echo $TSHG
if [ "$TSHG" != "[never]" ];then
	# generate a new profile for disable transparent_hugepage,CURRENT_TUNE_PROFILE is the current tune profile, NEW_TUNE_PROFILE is the new one
	CURRENT_TUNE_PROFILE=$(tuned-adm active | cut -d " " -f4)
	NEW_TUNE_PROFILE=$CURRENT_TUNE_PROFILE-oracle
	cp -R /usr/lib/tuned/$CURRENT_TUNE_PROFILE /usr/lib/tuned/$NEW_TUNE_PROFILE
	echo -e '[vm]\ntransparent_hugepages=never' >> /usr/lib/tuned/$NEW_TUNE_PROFILE/tuned.conf
	tuned-adm profile $NEW_TUNE_PROFILE
	tuned-adm active
	cat /sys/kernel/mm/transparent_hugepage/enabled
else
	echo "transparent_hugepage is already disabled"
fi

