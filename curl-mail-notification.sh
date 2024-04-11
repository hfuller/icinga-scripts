#!/usr/bin/env bash
# Icinga 2 | (c) 2012 Icinga GmbH | GPLv2+
# Except of function urlencode which is Copyright (C) by Brian White (brian@aljex.com) used under MIT license

PROG="`basename $0`"
ICINGA2HOST="`hostname`"
CURLBIN="curl"

if [ -z "`which $CURLBIN`" ] ; then
  echo "$CURLBIN not found in \$PATH. Consider installing it."
  exit 1
fi

## Function helpers
Usage() {
cat << EOF

Required parameters:
  -d LONGDATETIME (\$icinga.long_date_time\$)
  -e SERVICENAME (\$service.name\$)
  -l HOSTNAME (\$host.name\$)
  -n HOSTDISPLAYNAME (\$host.display_name\$)
  -o SERVICEOUTPUT (\$service.output\$)
  -r USEREMAIL (\$user.email\$)
  -s SERVICESTATE (\$service.state\$)
  -t NOTIFICATIONTYPE (\$notification.type\$)
  -u SERVICEDISPLAYNAME (\$service.display_name\$)
  -f MAILFROM (\$notification_mailfrom\$)

Optional parameters:
  -4 HOSTADDRESS (\$address\$)
  -6 HOSTADDRESS6 (\$address6\$)
  -b NOTIFICATIONAUTHORNAME (\$notification.author\$)
  -c NOTIFICATIONCOMMENT (\$notification.comment\$)
  -i ICINGAWEB2URL (\$notification_icingaweb2url\$, Default: unset)
  -v (\$notification_sendtosyslog\$, Default: false)

EOF
}

Help() {
  Usage;
  exit 0;
}

Error() {
  if [ "$1" ]; then
    echo $1
  fi
  Usage;
  exit 1;
}

urlencode() {
  local LANG=C i=0 c e s="$1"

  while [ $i -lt ${#1} ]; do
    [ "$i" -eq 0 ] || s="${s#?}"
    c=${s%"${s#?}"}
    [ -z "${c#[[:alnum:].~_-]}" ] || c=$(printf '%%%02X' "'$c")
    e="${e}${c}"
    i=$((i + 1))
  done
  echo "$e"
}

## Main
while getopts 4:6:b:c:d:e:f:hi:l:n:o:r:s:t:u:v:a:p: opt
do
  case "$opt" in
    4) HOSTADDRESS=$OPTARG ;;
    6) HOSTADDRESS6=$OPTARG ;;
    b) NOTIFICATIONAUTHORNAME=$OPTARG ;;
    c) NOTIFICATIONCOMMENT=$OPTARG ;;
    d) LONGDATETIME=$OPTARG ;; # required
    e) SERVICENAME=$OPTARG ;; # required
    f) MAILFROM=$OPTARG ;; # required
    h) Usage ;;
    i) ICINGAWEB2URL=$OPTARG ;;
    l) HOSTNAME=$OPTARG ;; # required
    n) HOSTDISPLAYNAME=$OPTARG ;; # required
    o) SERVICEOUTPUT=$OPTARG ;; # required
    r) USEREMAIL=$OPTARG ;; # required
    s) SERVICESTATE=$OPTARG ;; # required
    t) NOTIFICATIONTYPE=$OPTARG ;; # required
    u) SERVICEDISPLAYNAME=$OPTARG ;; # required
    v) VERBOSE=$OPTARG ;;
    a) SMTPUSER=$OPTARG ;; # required
    p) SMTPPASS=$OPTARG ;; # required
   \?) echo "ERROR: Invalid option -$OPTARG" >&2
       Usage ;;
    :) echo "Missing option argument for -$OPTARG" >&2
       Usage ;;
    *) echo "Unimplemented option: -$OPTARG" >&2
       Usage ;;
  esac
done

shift $((OPTIND - 1))

## Keep formatting in sync with mail-host-notification.sh
for P in LONGDATETIME HOSTNAME HOSTDISPLAYNAME SERVICENAME SERVICEDISPLAYNAME SERVICEOUTPUT SERVICESTATE USEREMAIL NOTIFICATIONTYPE MAILFROM SMTPUSER SMTPPASS ; do
        eval "PAR=\$${P}"

        if [ ! "$PAR" ] ; then
                Error "Required parameter '$P' is missing."
        fi
done

## Build the message's subject
SUBJECT="$NOTIFICATIONTYPE: Service $HOSTNAME/$SERVICEDISPLAYNAME is $SERVICESTATE [$(date +%s)]"

## Check whether IPv4 was specified.
if [ -n "$HOSTADDRESS" ] ; then
	THEREALADDRESS="$HOSTADDRESS"
fi

## Check whether IPv6 was specified.
if [ -n "$HOSTADDRESS6" ] ; then
	THEREALADDRESS="$HOSTADDRESS6"
fi

## Build the notification message
NOTIFICATION_MESSAGE=`cat << EOF
 -- $NOTIFICATIONTYPE --
$SERVICEDISPLAYNAME ($SERVICENAME) on the $HOSTDISPLAYNAME box ($THEREALADDRESS) is $SERVICESTATE as of $LONGDATETIME!

$SERVICEOUTPUT

EOF
`

## Check whether author and comment was specified.
if [ -n "$NOTIFICATIONCOMMENT" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE

Comment by $NOTIFICATIONAUTHORNAME:
  $NOTIFICATIONCOMMENT"
fi

## Check whether Icinga Web 2 URL was specified.
if [ -n "$ICINGAWEB2URL" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE

For more information, or if you are working this issue, click here:
$ICINGAWEB2URL/monitoring/service/show?host=$(urlencode "$HOSTNAME")&service=$(urlencode "$SERVICENAME")"
fi


## Check whether verbose mode was enabled and log to syslog.
if [ "$VERBOSE" = "true" ] ; then
  logger "$PROG sends $SUBJECT => $USEREMAIL"
fi

## Send the mail using the $CURLBIN command.
#TEMPFILE="$(mktemp /run/icinga2/mail.XXXXXXXXXX)"

echo "From: Icinga <$MAILFROM>
To: <$USEREMAIL>
Subject: $SUBJECT
Date: $(date -R)

$NOTIFICATION_MESSAGE" | $CURLBIN -v --ssl-reqd smtp://smtp.fastmail.com:587 --mail-from "$MAILFROM" --mail-rcpt "$USEREMAIL" --user "$SMTPUSER:$SMTPPASS" --upload-file -
#|tee -a "$TEMPFILE"

#rm -v "$TEMPFILE"
