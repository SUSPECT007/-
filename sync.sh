#!/bin/bash

# set -eux

dirA=./A
dirB=./B
Log=./log
logA=./logA
logB=./logB
log_tmp=log_t

walk_dir(){
    find $1 -printf "/%P\n"
}

reset(){
     echo >$1
}

initialize_log(){
  if [ ! -e "$Log" ]; then
    reset "$Log"
  fi
  if [ ! -e "$logA" ]; then
    reset "$logA"
  fi
  if [ ! -e "$logB" ]; then
    reset "$logB"
  fi
}

get_information(){
	stat -t $1$3 | awk '{ printf "%d\t", $13}'
	if [ -d $1$3 ]
	then
		ls -ld $1$3 | cut -c1 | awk '{ printf "%s\t", $1}'
		ls -ld $1$3 | cut -c2-10 | awk '{ printf "%s\t", $1}'
		ls -ld $1$3 | awk '{ printf "%s\t%s-%s-%s\t" , $5, $6, $7, $8 }'
	else
		ls -l $1$3 | cut -c1 | awk '{ printf "%s\t", $1}'
		ls -l $1$3 | cut -c2-10 | awk '{ printf "%s\t", $1}'
		ls -l $1$3 | awk '{ printf "%s\t%s-%s-%s\t" ,$5, $6, $7, $8 }'
	fi
	printf "$1$3\t\t"
	printf "$2$3\n"
}

update_log(){
	grep -v "$1$line" $Log > $log_tmp
	cat $log_tmp>$Log
	for i in `find $1$3`
	do
		echo $i
		name=${i/$1/}
		get_information $1 $2 $name>>$Log
	done
	echo "update $1$3 in log!"
}

get_log(){
	grep $1$2 $Log | awk '{print $1,$2,$3,$4}'
}

get_mtime(){
	stat -c %Y $1
}

get_metadata(){
  	get_information $1 $2 $3 | awk '{print $1,$2,$3,$4}'
}

get_file_authority(){
	get_information $1 $2 $3 | awk '{print $2, $3}'
}

get_log_authority(){
	grep $1$2 $Log | awk '{print $2, $3}'
}

handle_conflict(){
    echo "Choose:"
    echo "    (a) delete $1$3, save $2$3. "
    echo "    (b) save $1$3, delete $2$3. "
    echo "    (c) all delete. "
	read -n1 -p "your choice: " input </dev/tty
	case $input in
		a)
			rm -rf $1$3
			copy_with_metainfo $2 $1 $3
			echo "Delete $1$3, save $2$3 !!!";;
		b)
			rm -rf $2$3
			copy_with_metainfo $1 $2 $3
                        echo "Delete $2$3, save $1$3 !!!";;
		c)
			rm -rf $1$3
			rm -rf $2$3
			copy_with_metainfo $1 $2 $3
			echo "Delete both files !!!";;
		*)
			echo "\n Error option!!! Please input again."
			handle_conflict $1 $2 $3
	esac
}

copy_with_metainfo(){
	cp -rpf $1$3 `dirname $2$3`
	echo "copy $1$3 to $2$3 !"
	update_log $1 $2 $3
}

compare_file(){
while read line
do
	echo $line
	if [ -e $2$line ]
	then
		echo "$2$line exist!!"
		if [[ -f $1$line && -f $2$line ]]
		then
			echo "$1$line and $2$line are ordinary files "
			if [[ `get_metadata $1 $2 $line` = `get_log $1 $line` && `get_metadata $2 $1 $line` = `get_log $2 $line` ]]
			then
				echo "file $line in A and B are not changed!!!"
			elif [[ `get_metadata $1 $2 $line` = `get_log $1 $line` || `get_metadata $2 $1 $line` = `get_log $2 $line` ]]
			then
				echo "compare `get_metadata $1 $2 $line` and `get_log $1 $line`"
				echo "compare `get_metadata $2 $1 $line` and `get_log $2 $line`"
				if [ `get_mtime $1$line` -ne `get_mtime $2$line` ]
				then
					echo "mtime of $1$line and $2$line are not same!"
					if [ `get_mtime $1$line` -gt `get_mtime $2$line` ]
					then
						echo "mtime of $1$line greater than $2$line!! "
						copy_with_metainfo $1 $2 $line
					else
						echo "mtime of $2$line greater than $1$line!! "
						copy_with_metainfo $2 $1 $line
					fi
				else
					echo "mtime of $1$line and $2$line are same but metadata are not same!"
					if [[ `get_file_authority $1 $2 $line` = `get_log_authority $1 $line` && `get_file_authority $2 $1 $line` != `get_log_authority $2 $line` ]]
					then
						echo "The authority of $2$line has been changed!!"
						copy_with_metainfo $2 $1 $line
					elif [[ `get_file_authority $1 $2 $line` != `get_log_authority $1 $line` && `get_file_authority $2 $1 $line` = `get_log_authority $2 $line` ]]
					then
						echo "The authority of $1$line has been changed!!"
						copy_with_metainfo $1 $2 $line
					else
						echo "Other metadata has been changed!!"
					fi
				fi
			else
				echo "compare `get_metadata $1 $2 $line` and `get_log $1 $line`"
				echo "compare `get_metadata $2 $1 $line` and `get_log $2 $line`"
				echo "Error: $1$line and $2$line have confilt."
				if [[ -r $1$line && -r $2$line ]]
				then
					if [ "`diff $1$line $2$line`" = "" ]
					then
						echo "File $1$line and $2$line have same content!!"
						if [[ `get_file_authority $1 $2 $line` = `get_log_authority $1 $line` && `get_file_authority $2 $1 $line` = "`get_log_authority $2 $line`" ]]
						then
							echo "File $1$line and $2$line have same metadata!!"
							if [ `get_mtime $1$line` -ge `get_mtime $2$line` ]
							then
								echo "Metadata of $1$line greater than $2$line"
								copy_with_metainfo $1 $2 $line
							else
								echo "Metadata of $2$line greater than $1$line"
								copy_with_metainfo $2 $1 $line
							fi
						elif [[  "`get_file_authority $1 $2 $line`" = "`get_log_authority $1 $line`" && "`get_file_authority $2 $1 $line`" != "`get_log_authority $2 $line`" ]]
						then
							echo "File $1$line and log have same metadata but $2$line not!!"
							copy_with_metainfo $2 $1 $line
						elif [[ "`get_file_authority $1 $2 $line`" != "`get_log_authority $1 $line`" && "`get_file_authority $2 $1 $line`" = "`get_log_authority $2 $line`" ]]
						then
							echo "File $2$line and log have same metadata but $1$line not!!"
							copy_with_metainfo $1 $2 $line
						else
							echo "The authority of $line are not same!!"
							echo "The authority of $1$line is `get_file_authority $1 $2 $line`"
							echo "The authority of $2$line is `get_file_authority $2 $1 $line`"
							handle_conflict $1 $2 $line
						fi
					else
						echo "File $1$line and $2$line have not same content!!"
						diff -c $1$line $2$line
						handle_conflict $1 $2 $line
					fi
				else
					echo "File $1$line and $2$line can not be read!!"
					copy_with_metainfo $1 $2 $line
				fi
			fi
		else
			if [[ -d $1$line && -f $2$line ]]
			then
				echo "Error: $1$line is directory file but $2$line is ordinary file!!"
				handle_conflict $1 $2 $line
			elif [[ -f $1$line && -d $2$line ]]
			then
				echo "Error: $2$line is directory file but $1$line is ordinary file!!"
				handle_conflict $2 $1 $line
			elif [[ -d $1$line && -d $2$line ]]
			then
				echo "File $1$line and $2$line are directory files!!"
			else
				echo "File $1$line and $2$line are other types!!!!"
			fi
		fi
	else
		echo "$2$line not found!"
		if [ -e $1$line ]
		then
			if [ "`grep $1$line $Log`" != "" ]
			then
				rm -rf $1$line
				echo "Can not find $1$line in $2 but in log. Delete $1$line"
				update_log $1 $2 $line
			else
				echo "Can not find $1$line in $2 and in log. It is a new file."
				copy_with_metainfo $1 $2 $line
			fi
		else
			echo "$1$line is not exist!! "
		fi
	fi
done<$3
}

initialize_log
echo "sync A with log==========="
cat $Log
walk_dir $dirA > $logA
compare_file $dirA $dirB $logA

echo "sync B with log==========="
cat $Log
walk_dir $dirB > $logB
compare_file $dirB $dirA $logB

echo "print the log============="
cat $Log
walk_dir $dirA > $logA
walk_dir $dirB > $logB

rm $logA $logB
