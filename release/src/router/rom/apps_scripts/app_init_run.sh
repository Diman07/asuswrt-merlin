#!/bin/sh
# $1: Package name/allpkg, $2: action.


APPS_PATH=/opt
APPS_RUN_DIR=$APPS_PATH/etc/init.d
APPS_MOUNTED_PATH=`nvram get apps_mounted_path`
APP_FS_TYPE=`mount | grep $APPS_MOUNTED_PATH | sed -e "s,.*on.* type \([^ ]*\) (.*$,\1,"`

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Usage: app_init_run.sh <Package name|allpkg> <action>"
	exit 1
fi

if [ ! -d "$APPS_RUN_DIR" ]; then
	echo "The APP's init dir was not existed!"
	exit 1
fi

if [ "$2" == "stop" ]; then
	while true ; do
		PIDS1=`ps|grep "sh.*/\(\.asusrouter\|app_base_link.sh\|app_update.sh\|app_init_run.sh.*start\)"|grep -v grep|awk '{print $1}'`
		PIDS2=`ps|grep "sh.*/opt/etc/init\.d/S.*start"|grep -v grep|awk '{print $1}'`
		PIDS3=`ps|grep "ch\(mod\|own\).*/tmp/mnt"|grep -v grep|awk '{print $1}'`
		PIDS4=`ps|grep "wget.*asus"|grep -v grep|awk '{print $1}'`
		PIDS5=`ps|grep "[^[]watch_app"|grep -v grep|awk '{print $1}'`
		PIDS=`echo $PIDS1 $PIDS2 $PIDS3 $PIDS4 $PIDS5 | tr  '\n' ' '`

		if [ -z "`echo $PIDS | tr -d ' \n\t\f\r'`" ] ; then
			break;
		fi

		kill -TERM $PIDS
		sleep 1
		kill -KILL $PIDS
	done
fi

for f in $APPS_RUN_DIR/S*; do
	s="/opt/"`basename $f`.1
	[ -e "$s" ] && rm -f $s
	if [ "$APP_FS_TYPE" == "fuseblk" ] ; then
		sed -e "s,\(chmod.*\),echo skip \1," -e "s,\(chown.*\),echo skip \1," -e "s,/opt/etc/init\.d/\(S50[^. ]*\),/opt/\1.1," $f > $s
	else
		cp -f $f $s
	fi
done

for f in $APPS_RUN_DIR/S*; do
	s=$f
	tmp_apps_name=`get_apps_name $f`
	if [ "$1" != "allpkg" ] && [ "$1" != "$tmp_apps_name" ]; then
		continue
	fi

	if [ "$2" == "start" ]; then
		app_enable=`app_get_field.sh $tmp_apps_name "Enabled" 1`
		if [ "$app_enable" != "yes" ]; then
			if [ "$1" != "allpkg" ] && [ "$1" == "$tmp_apps_name" ]; then
				echo "No permission to start with the app: $1!"
				exit 1
			fi

			continue
		fi
	fi

	s="/opt/"`basename $f`.1
	[ ! -e "$s" ] && s=$f

	nice_cmd=
	if [ "$tmp_apps_name" == "downloadmaster" ]; then
		nice_cmd="nice -n 19"
	fi

	echo "$nice_cmd sh $s $2" | logger -c
	$nice_cmd sh $s $2

	if [ "$1" != "allpkg" ] && [ "$1" == "$tmp_apps_name" ]; then
		break
	fi
done

dm2_trans_array=`ps|grep dm2_trans|grep -v grep|awk '{print $1}'`
for tran in $dm2_trans_array; do
	ionice -c3 -p $tran
done

