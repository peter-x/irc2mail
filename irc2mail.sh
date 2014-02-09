#!/bin/bash

################################################################################
# Usage: irc2mail.sh <file> <max age>
#
# Parses the given irssi log file <file> and checks if there are any messages
# that are younger than <max age> minutes. If yes, it prints a header containing
# the file name (typically the channel name), followed by all those messages.
#
# It can be used in cron scripts to periodically send channel messages via mail.
################################################################################


logfile="$1"
interval="$2"


# we need this because "date" is not smart enough to parse irssi's localized
# date strings
parseMonth()
{
    for m in {1..12}; do
        if [ $(date -d "2000-$m-1" "+%b") = "$1" ]
        then
            echo -n $m
            break
        fi
    done
}

openedOrDayChangedRegex="^(Log opened|Day changed) [^ ]+ ([^ ]+) ([0-9]+) \
([0-9][0-9]:[0-9][0-9]:[0-9][0-9] )?([0-9]{4})"

printedHeader=
maxAge=$((10#$interval * 60 ))
currentTime=$(date +%s)
dayStart=0
# remove system messages (join/part/...) and parse regular messages
grep -v '^[0-9][0-9]:[0-9][0-9] -!- ' < "$logfile" | while read time message
do
    if [[ "$message" =~ $openedOrDayChangedRegex ]]
    then
        month=$(parseMonth ${BASH_REMATCH[2]})
        day=${BASH_REMATCH[3]}
        year=${BASH_REMATCH[5]}
        date --date="$year-$month-$day 00:00:00" +%s >/dev/null 2>&1 || continue
        dayStart=$(date --date="$year-$month-$day 00:00:00" +%s)
    elif [[ "$time" =~ ^([0-9][0-9]):([0-9][0-9]) ]]
    then
        hour=${time%%:*}
        minute=${time##*:}
        age=$((currentTime - (10#$dayStart + 10#$hour * 3600 + 10#$minute * 60)))

        if [ "$age" -lt "$maxAge" ]
        then
            if [ -z "$printedHeader" ]
            then
                echo "Messages in   $logfile   from the last $interval minutes:"
                echo
                printedHeader=1
            fi
            echo "$time $message"
        fi
    fi
done
