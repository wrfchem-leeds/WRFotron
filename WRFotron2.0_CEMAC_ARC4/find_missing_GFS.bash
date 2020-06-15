# this bash script finds out which GFS files are missing
# first creates an array of all the filenames and then loops through them using the fillin script
unset 'array'
dataDir=/nobackup/user/wrf3.7.1_data/initial_boundary_meteo/
cd $dataDir
for month in $(seq -w 1 12)
do
for day in $(seq -w 1 31)
do
for hour in $(seq -w 0 3 21)
do
filename=$(date -u --date="2015-01-01 00:00:00 ${month} months ${day} days ${hour} hours" "+GF%Y%m%d%H")
    if [ ! -f $dataDir${filename} ]
    then
      echo "${filename} is missing"
      array+=(${filename})
    fi
done
done
done

for i in "${array[@]}"
do
  cd /home/ufaserv1_i/user/wrf3.7.1_code/download_and_find_gfs_mz4
  . get_GFS_fillin.bash ${i:2:4} ${i:6:2} ${i:8:2} ${i:10:2}
  cd /home/ufaserv1_i/user/wrf3.7.1_code/download_and_find_gfs_mz4
done
