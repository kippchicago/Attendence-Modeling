#!/bin/bash

#shell script that cleans or polishes NWEA provided comprehensive data files (CDFs) for loading into a MySQL Database

#USAGE| map_cdf_prep.sh foo.csv
#     | for mulitple files at at time: for file in *.csv; do map_cdf_prep.sh $file; done
#input| foo.csv, which is any CDF csv
#output| foo_loaddata.csv, a csv ready to load into a MySQL data base. 

#partion and save file name into twoparts (for foo.csv, first = foo and rest = .csv)
first=`echo $1 | sed 's|\(.*\)\(\..*\)|\1|'`
rest=`echo $1 | sed 's|\(.*\)\(\..*\)|\2|'`

newfile=$first'_loaddata'$rest

#remove stupid DOS formatting (paritcularly the ^M new line command ) or post Fall 2012 Web based map.  This line can be commented out for 
#any CDF files prior to Fall 2012
tr '\r' '\n' <$1 >$newfile
#long sed using regexp to remove spaces and slashes, commas, and slashes for cells. Also replaces cells that are empty or contain ", BR, * with \N, then deletes the first line of the file.
sed -E -i "" -e 's|_NumSense_,NumSense,||g'  -e 's|,Stat/Prob,|_Stat_Prob_|g' -e 's|,Phonic,|_Phonic_|g'  -e 's|,"",|,\\N,|g' -e 's|"||g' -e 's|BR|\\N|g' -e 's|, Statistics, and Probability|_Statistics_and_Probability|g' -e 's| Grammar, Spelling|_Grammar_Spelling|g' -e 's| Punctuation, Cap., Struct.|_Punctuation_Cap_Struct|g' -e 's|Science - General Science|General Science|g' $newfile

#remove first line of table headers f 
sed -i "" '1d' $newfile  
#messsage upon completion
echo 'Data from '$1' cleaned and saved to '$newfile'. BOOYAH. Time Saved!'


