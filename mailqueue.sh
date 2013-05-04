#!/bin/bash

# output the number of messages in the incoming, active, and deferred
# queues of postfix one per line suitable for use with snmpd/cricket/rrdtool
#
# 2003/01/24 Mike Saunders <method at method DOT cx>
#            mailqsize was originally written by Vivek Khera.  All I did was
#            make it update an rrd.
# 2003/04/14 Ralf Hildebrandt <ralf.hildebrandt at charite DOT de>
#            I bundled this with a modified mailgraph
# 2007/07/28 Ralf Hildebrandt <ralf.hildebrandt at charite DOT de>
#            find rrdtool using "which"
# 2013/05/04 Tobias Hachmer <network at kokelnet DOT de>
#            "rewrite" script to log values to syslog. This
#	     makes it possible to parse them with mailgraph script

# find where logger binary is
LOGGER=`which logger`
queuedir=`/usr/sbin/postconf -h queue_directory`

active=`find $queuedir/incoming $queuedir/active $queuedir/maildrop -type f -print | wc -l | awk '{print $1}'`
deferred=`find $queuedir/deferred -type f -print | wc -l | awk '{print $1}'`

$LOGGER -t mailqueue active: $active, deferred: $deferred
