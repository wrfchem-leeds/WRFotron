#this bash script finds out which files are missing, called through . finddate.bash
#would need to change the date, and the amount of expected hours
for hour in $(seq -w 0 696)
do
filename=$(date -u --date="2016-02-01 00:00:00 ${hour} hours" "+wrfout_d01_%Y-%m-%d_%H:00:00")
    if [ ! -f ${filename} ]
    then
      echo "${filename} is missing"
    fi
done
