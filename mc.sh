#!/bin/bash
# /usr/bin/mc
: '
/**
 *
 * Minecraft control script.
 * This script MUST be in your path!
 * All paths should be absolute.
 *
 * @author Dan Hlavenka
 * @version 2012-10-11 20:20 CST
 *
 */

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!    Requires `screen` to work at all.     !!
!! Requires `s3cmd` to back up to Amazon S3 !!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
'

base_dir="/home/$USER/mc"
java_path="/java/bin/java"
minecraft_path="/home/$USER/mc/bukkit.jar"
memory="8G"
update_url="http://cbukk.it/craftbukkit.jar"
beta_update_url="http://cbukk.it/craftbukkit-beta.jar"
dev_update_url="http://cbukk.it/craftbukkit-dev.jar"
s3_bucket="" # Set to "" to bypass S3 backups
opts="-Djava.awt.headless=true" # Extra options to pass to Java

cd $base_dir

start(){
	if [ "$(status)" = "Running" ]; then
		echo "ERROR: Already running"
	else
		screen -dmS mc mc run
		while [ "$(status)" != "Running" ]; do
			[ ] # Wait for Java to start
		done
		echo "Server started."
	fi
}

stop(){
	if [ "$(status)" = "Running" ]; then
		screen -S mc -X eval "stuff 'stop'\015"
		while [ "$(status)" = "Running" ]; do
			[ ] # Wait for Java to terminate
		done
		echo "Server stopped"
	else
		echo "ERROR: Not running"
	fi
}

status(){
	if [ "`pidof -s java`" ]; then
		echo "Running"
	else
		echo "Not running"
	fi
}

case "$1" in
	start)
		echo $(start)
		;;
	run)
		$java_path -Xmx$memory -Xms$memory $opts -jar $minecraft_path
		;;
	join)
		if [ "$(status)" = "Running" ]; then
			screen -dr mc
		else
			echo "ERROR: Not running"
		fi
		;;
	watch)
		tail -f $base_dir/server.log
		;;
	tail)
		tail -n 20 $base_dir/server.log
		;;
	stop)
		echo $(stop)
		;;
	kill)
		if [ "$(status)" = "Running" ]; then
			echo "Killing server..."
			kill -9 `pidof java`
			while [ "$(status)" = "Running" ]; do
				[ ] # Wait for Java to terminate
			done
			echo "Server stopped"
		else
			echo "ERROR: Not running"
		fi
		;;
	restart)
		if [ "$(status)" = "Running" ]; then
			$(stop)
		fi
		$(start)
		;;
	backup)
		screen -S mc -X eval "stuff 'broadcast Starting backup...'\015"
		screen -S mc -X eval "stuff 'save-off'\015"
		screen -S mc -X eval "stuff 'save-all'\015"
		archive=$base_dir/backups/`date "+%Y-%m-%d-%H-%M"`.zip
		zip -q $archive -r world
		screen -S mc -X eval "stuff 'save-on'\015"
		screen -S mc -X eval "stuff 'broadcast Backup complete!'\015"
		if [ $s3_bucket ]; then
			s3cmd put --add-header=x-amz-storage-class:REDUCED_REDUNDANCY $archive s3://$s3_bucket/backups/
		fi
		if [ $gs_bucket ]; then
			gsutil cp -a public-read $archive gs://$gs_bucket/backups/
		fi
		echo "Backup complete"
		;;
	update)
		rm $minecraft_path
		case "$2" in
			beta)
				wget -O $minecraft_path $beta_update_url
				;;
			dev)
				wget -O $minecraft_path $dev_update_url
				;;
			*)
				wget -O $minecraft_path $update_url
				;;
		esac
		chmod +x $minecraft_path
		if [ "$(status)" = "Running" ]; then
			$(restart)
		fi
		echo "Update complete"
		;;
	status)
		echo $(status)
		;;
	*)
		echo "Status:" $(status)
		echo "Options:"
		echo "       mc start : Starts the server"
		echo "        mc join : Brings the server console to your active window"
		echo "       mc watch : Monitors the console output without attaching"
		echo "        mc tail : Displays the last 20 lines of the server log"
		echo "        mc stop : Stops the server gracefully"
		echo "        mc kill : Kills the server immediately"
		echo "     mc restart : Stops the server gracefully, then restarts"
		echo "      mc update : Updates to the latest Recommended build"
		echo " mc update beta : Updates to the latest Beta build"
		echo "  mc update dev : Updates to the latest Development build"
		echo "      mc backup : Saves a copy of the world to ~/backups"
		echo "      mc status : Returns the server status ('running' / 'not running')"
		;;
esac