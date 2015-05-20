#!/usr/bin/perl -w

# mailgraph -- postfix mail traffic statistics
# copyright (c) 2013 KokelNET
# copyright (c) 2013 Tobias Hachmer <network@kokelnet.de>
# copyright (c) 2000-2007 ETH Zurich
# copyright (c) 2000-2007 David Schweikert <david@schweikert.ch>
# released under the GNU General Public License

use RRDs;
use strict;
use Getopt::Long;
use POSIX qw(uname);
my $VERSION = "0.1";

my $host = (POSIX::uname())[1];
my $company = 'KokelNET - Network Communications';
my $scriptname = 'create_mailgraph_pics.pl';
my $xpoints = 540;
my $points_per_sample = 3;
my $ypoints = 160;
my $ypoints_err = 96;
my $ypoints_grey = 96;
my $ypoints_queue = 96;
my $ypoints_imap = 96;
my $ypoints_proto = 96;
my $rrd = '/var/lib/mailgraph/mailgraph.rrd'; # path to where the RRD database is
my $rrd_virus = '/var/lib/mailgraph/mailgraph_virus.rrd'; # path to where the Virus RRD database is
my $rrd_greylist = '/var/lib/mailgraph/mailgraph_greylist.rrd'; # path to where the Greylist RRD database is
my $rrd_queue = '/var/lib/mailgraph/mailgraph_queue.rrd'; # path to where the Queue RRD database is
my $rrd_imap = '/var/lib/mailgraph/mailgraph_imap.rrd'; # path to where the IMAP RRD database is
my $tmp_dir = '/var/cache/mailgraph'; # temporary directory where to store the images


my @graphs = (
	{ title => 'Last Day', seconds => 3600*24,	     },
	{ title => 'Last Week', seconds => 3600*24*7,        },
	{ title => 'Last Month', seconds => 3600*24*31,      },
	{ title => 'Last 6 Months', seconds => 3600*24*31*6, },
	{ title => 'Last Year', seconds => 3600*24*31*12,    },
);

my %color = (
	sent     	=> '000099', # rrggbb in hex
	received 	=> '009900',
	delivered	=> '009900',
	rejected 	=> 'AA0000', 
	bounced  	=> '000000',
	virus    	=> 'DDBB00',
	spam     	=> '999999',
        greylisted 	=> '999999',
	active		=> '00ff00',
	deferred	=> '0000ff',
	delayed 	=> '006400',
        ipv4            => '00FF00',
        ipv6            => '3399FF',
        imaplogin       => '009900',
        imaplogintls    => '22C9BA',
        imaploginall    => '22C9BA',
        imaploginfailed => 'FF0000',
        pop3login       => 'FFBF00',
        pop3logintls    => 'FFFF00',
        pop3loginall    => 'FFFF00',
        pop3loginfailed => 'FF0000',
        pop3loginfailedall => 'CE00FF',
);

sub rrd_graph(@)
{
	my ($range, $file, $ypoints, @rrdargs) = @_;
	my $step = $range*$points_per_sample/$xpoints;
	# choose carefully the end otherwise rrd will maybe pick the wrong RRA:
	my $end  = time; $end -= $end % $step;
	my $date = localtime(time);
	$date =~ s|:|\\:|g unless $RRDs::VERSION < 1.199908;

	my ($graphret,$xs,$ys) = RRDs::graph($file,
		'--imgformat', 'PNG',
		'--width', $xpoints,
		'--height', $ypoints,
		'--start', "-$range",
		'--end', $end,
		'--vertical-label', 'msgs/min',
		'--lower-limit', 0,
		'--units-exponent', 0, # don't show milli-messages/s
		'--lazy',
		'--color', 'SHADEA#ffffff',
		'--color', 'SHADEB#ffffff',
		'--color', 'BACK#ffffff',
                '--watermark='.$company,
                '--title='.$host,

		$RRDs::VERSION < 1.2002 ? () : ( '--slope-mode'),

		@rrdargs,

		'COMMENT:['.$date.']\r',
	);

	my $ERR=RRDs::error;
	die "ERROR: $ERR\n" if $ERR;
}

sub graph($$)
{
	my ($range, $file) = @_;
	my $step = $range*$points_per_sample/$xpoints;
		rrd_graph($range, $file, $ypoints,
	                "DEF:recv=$rrd:recv:AVERAGE",
        	        "DEF:mrecv=$rrd:recv:MAX",
               		"CDEF:rrecv=recv,60,*",
                	"CDEF:rmrecv=mrecv,60,*",
                	"CDEF:drecv=recv,UN,0,recv,IF,$step,*",
                	"CDEF:srecv=PREV,UN,drecv,PREV,IF,drecv,+",
                	"AREA:rrecv#$color{received}:Inbound ",
                	'GPRINT:srecv:MAX:total\: %8.0lf msgs',
                	'GPRINT:rrecv:AVERAGE:avg\: %5.2lf msgs/min',
                	'GPRINT:rmrecv:MAX:max\: %4.0lf msgs/min\l',

			"DEF:sent=$rrd:sent:AVERAGE",
			"DEF:msent=$rrd:sent:MAX",
			"CDEF:rsent=sent,60,*",
			"CDEF:rmsent=msent,60,*",
			"CDEF:dsent=sent,UN,0,sent,IF,$step,*",
			"CDEF:ssent=PREV,UN,dsent,PREV,IF,dsent,+",
			"LINE2:rsent#$color{sent}:Outbound",
			'GPRINT:ssent:MAX:total\: %8.0lf msgs',
			'GPRINT:rsent:AVERAGE:avg\: %5.2lf msgs/min',
			'GPRINT:rmsent:MAX:max\: %4.0lf msgs/min\l',
		);
}

sub graph_queue($$)
{
	my ($range, $file) = @_;
	my $step = $range*$points_per_sample/$xpoints;
		rrd_graph($range, $file, $ypoints_queue,
	                "DEF:active=$rrd_queue:active:AVERAGE",
        	        "DEF:mactive=$rrd_queue:active:MAX",
               		"CDEF:ractive=active,60,*",
                	"CDEF:rmactive=mactive,60,*",
                	"CDEF:dactive=active,UN,0,active,IF,$step,*",
                	"CDEF:sactive=PREV,UN,dactive,PREV,IF,dactive,+",
                	"AREA:ractive#$color{active}:Active+Incoming+Maildrop",
                	'GPRINT:sactive:MAX:total\: %4.0lf msgs',
                	'GPRINT:ractive:AVERAGE:avg\: %5.2lf msgs/min',
                	'GPRINT:rmactive:MAX:max\: %4.0lf msgs/min\l',

			"DEF:deferred=$rrd_queue:deferred:AVERAGE",
			"DEF:mdeferred=$rrd_queue:deferred:MAX",
			"CDEF:rdeferred=deferred,60,*",
			"CDEF:rmdeferred=mdeferred,60,*",
			"CDEF:ddeferred=deferred,UN,0,deferred,IF,$step,*",
			"CDEF:sdeferred=PREV,UN,ddeferred,PREV,IF,ddeferred,+",
			"LINE2:rdeferred#$color{deferred}:Deferred                ",
			'GPRINT:sdeferred:MAX:total\: %4.0lf msgs',
			'GPRINT:rdeferred:AVERAGE:avg\: %5.2lf msgs/min',
			'GPRINT:rmdeferred:MAX:max\: %4.0lf msgs/min\l',
		);
}


sub graph_proto($$)
{
        my ($range, $file) = @_;
        my $step = $range*$points_per_sample/$xpoints;
                rrd_graph($range, $file, $ypoints_proto,
                        "DEF:ipv4=$rrd:ipv4:AVERAGE",
                        "DEF:mipv4=$rrd:ipv4:MAX",
                        "CDEF:ripv4=ipv4,60,*",
                        "CDEF:rmipv4=mipv4,60,*",
                        "CDEF:dipv4=ipv4,UN,0,ipv4,IF,$step,*",
                        "CDEF:sipv4=PREV,UN,dipv4,PREV,IF,dipv4,+",
                        "LINE2:ripv4#$color{ipv4}:IPv4 ",
                        'GPRINT:sipv4:MAX:total\: %8.0lf msgs',
                        'GPRINT:ripv4:AVERAGE:avg\: %5.2lf msgs/min',
                        'GPRINT:rmipv4:MAX:max\: %4.0lf msgs/min\l',

                        "DEF:ipv6=$rrd:ipv6:AVERAGE",
                        "DEF:mipv6=$rrd:ipv6:MAX",
                        "CDEF:ripv6=ipv6,60,*",
                        "CDEF:rmipv6=mipv6,60,*",
                        "CDEF:dipv6=ipv6,UN,0,ipv6,IF,$step,*",
                        "CDEF:sipv6=PREV,UN,dipv6,PREV,IF,dipv6,+",
                        "LINE2:ripv6#$color{ipv6}:IPv6 ",
                        'GPRINT:sipv6:MAX:total\: %8.0lf msgs',
                        'GPRINT:ripv6:AVERAGE:avg\: %5.2lf msgs/min',
                        'GPRINT:rmipv6:MAX:max\: %4.0lf msgs/min\l',
                );
}

sub graph_imapserver($$)
{
        my ($range, $file) = @_;
        my $step = $range*$points_per_sample/$xpoints;
                rrd_graph($range, $file, $ypoints,
                        "DEF:delivered=$rrd:delivered:AVERAGE",
                        "DEF:mdelivered=$rrd:delivered:MAX",
                        "CDEF:rdelivered=delivered,60,*",
                        "CDEF:rmdelivered=mdelivered,60,*",
                        "CDEF:ddelivered=recv,UN,0,delivered,IF,$step,*",
                        "CDEF:sdelivered=PREV,UN,ddelivered,PREV,IF,ddelivered,+",
                        "AREA:rdelivered#$color{delivered}:Delivered",
                        'GPRINT:sdelivered:MAX:total\: %8.0lf msgs',
                        'GPRINT:rdelivered:AVERAGE:avg\: %5.2lf msgs/min',
                        'GPRINT:rmdelivered:MAX:max\: %4.0lf msgs/min\l',

                        "DEF:sent=$rrd:sent:AVERAGE",
                        "DEF:msent=$rrd:sent:MAX",
                        "CDEF:rsent=sent,60,*",
                        "CDEF:rmsent=msent,60,*",
                        "CDEF:dsent=sent,UN,0,sent,IF,$step,*",
                        "CDEF:ssent=PREV,UN,dsent,PREV,IF,dsent,+",
                        "LINE2:rsent#$color{sent}:Sent    ",
                        'GPRINT:ssent:MAX:total\: %8.0lf msgs',
                        'GPRINT:rsent:AVERAGE:avg\: %5.2lf msgs/min',
                        'GPRINT:rmsent:MAX:max\: %4.0lf msgs/min\l',
                );
}


sub graph_err($$)
{
	my ($range, $file) = @_;
	my $step = $range*$points_per_sample/$xpoints;
		rrd_graph($range, $file, $ypoints_err,
			"DEF:bounced=$rrd:bounced:AVERAGE",
			"DEF:mbounced=$rrd:bounced:MAX",
			"CDEF:rbounced=bounced,60,*",
			"CDEF:dbounced=bounced,UN,0,bounced,IF,$step,*",
			"CDEF:sbounced=PREV,UN,dbounced,PREV,IF,dbounced,+",
			"CDEF:rmbounced=mbounced,60,*",
			"AREA:rbounced#$color{bounced}:Bounced ",
			'GPRINT:sbounced:MAX:total\: %8.0lf msgs',
			'GPRINT:rbounced:AVERAGE:avg\: %5.2lf msgs/min',
			'GPRINT:rmbounced:MAX:max\: %4.0lf msgs/min\l',

			"DEF:virus=$rrd_virus:virus:AVERAGE",
			"DEF:mvirus=$rrd_virus:virus:MAX",
			"CDEF:rvirus=virus,60,*",
			"CDEF:dvirus=virus,UN,0,virus,IF,$step,*",
			"CDEF:svirus=PREV,UN,dvirus,PREV,IF,dvirus,+",
			"CDEF:rmvirus=mvirus,60,*",
			"STACK:rvirus#$color{virus}:Viruses ",
			'GPRINT:svirus:MAX:total\: %8.0lf msgs',
			'GPRINT:rvirus:AVERAGE:avg\: %5.2lf msgs/min',
			'GPRINT:rmvirus:MAX:max\: %4.0lf msgs/min\l',

			"DEF:spam=$rrd_virus:spam:AVERAGE",
			"DEF:mspam=$rrd_virus:spam:MAX",
			"CDEF:rspam=spam,60,*",
			"CDEF:dspam=spam,UN,0,spam,IF,$step,*",
			"CDEF:sspam=PREV,UN,dspam,PREV,IF,dspam,+",
			"CDEF:rmspam=mspam,60,*",
			"STACK:rspam#$color{spam}:Spam    ",
			'GPRINT:sspam:MAX:total\: %8.0lf msgs',
			'GPRINT:rspam:AVERAGE:avg\: %5.2lf msgs/min',
			'GPRINT:rmspam:MAX:max\: %4.0lf msgs/min\l',

			"DEF:rejected=$rrd:rejected:AVERAGE",
			"DEF:mrejected=$rrd:rejected:MAX",
			"CDEF:rrejected=rejected,60,*",
			"CDEF:drejected=rejected,UN,0,rejected,IF,$step,*",
			"CDEF:srejected=PREV,UN,drejected,PREV,IF,drejected,+",
			"CDEF:rmrejected=mrejected,60,*",
			"LINE2:rrejected#$color{rejected}:Rejected",
			'GPRINT:srejected:MAX:total\: %8.0lf msgs',
			'GPRINT:rrejected:AVERAGE:avg\: %5.2lf msgs/min',
			'GPRINT:rmrejected:MAX:max\: %4.0lf msgs/min\l',
		);
}

sub graph_imap_err($$)
{
        my ($range, $file) = @_;
        my $step = $range*$points_per_sample/$xpoints;
                rrd_graph($range, $file, $ypoints_err,
                        "DEF:bounced=$rrd:bounced:AVERAGE",
                        "DEF:mbounced=$rrd:bounced:MAX",
                        "CDEF:rbounced=bounced,60,*",
                        "CDEF:dbounced=bounced,UN,0,bounced,IF,$step,*",
                        "CDEF:sbounced=PREV,UN,dbounced,PREV,IF,dbounced,+",
                        "CDEF:rmbounced=mbounced,60,*",
                        "AREA:rbounced#$color{bounced}:Bounced ",
                        'GPRINT:sbounced:MAX:total\: %8.0lf msgs',
                        'GPRINT:rbounced:AVERAGE:avg\: %5.2lf msgs/min',
                        'GPRINT:rmbounced:MAX:max\: %4.0lf msgs/min\l',

                        "DEF:rejected=$rrd:rejected:AVERAGE",
                        "DEF:mrejected=$rrd:rejected:MAX",
                        "CDEF:rrejected=rejected,60,*",
                        "CDEF:drejected=rejected,UN,0,rejected,IF,$step,*",
                        "CDEF:srejected=PREV,UN,drejected,PREV,IF,drejected,+",
                        "CDEF:rmrejected=mrejected,60,*",
                        "LINE2:rrejected#$color{rejected}:Rejected",
                        'GPRINT:srejected:MAX:total\: %8.0lf msgs',
                        'GPRINT:rrejected:AVERAGE:avg\: %5.2lf msgs/min',
                        'GPRINT:rmrejected:MAX:max\: %4.0lf msgs/min\l',
		);
}

sub graph_grey($$)
{
        my ($range, $file) = @_;
        my $step = $range*$points_per_sample/$xpoints;
        rrd_graph($range, $file, $ypoints_grey,
                "DEF:greylisted=$rrd_greylist:greylisted:AVERAGE",
                "DEF:mgreylisted=$rrd_greylist:greylisted:MAX",
                "CDEF:rgreylisted=greylisted,60,*",
                "CDEF:dgreylisted=greylisted,UN,0,greylisted,IF,$step,*",
                "CDEF:sgreylisted=PREV,UN,dgreylisted,PREV,IF,dgreylisted,+",
                "CDEF:rmgreylisted=mgreylisted,60,*",
                "AREA:rgreylisted#$color{greylisted}:Greylisted",
                'GPRINT:sgreylisted:MAX:total\: %8.0lf msgs',
                'GPRINT:rgreylisted:AVERAGE:avg\: %5.2lf msgs/min',
                'GPRINT:rmgreylisted:MAX:max\: %4.0lf msgs/min\l',

                "DEF:delayed=$rrd_greylist:delayed:AVERAGE",
                "DEF:mdelayed=$rrd_greylist:delayed:MAX",
                "CDEF:rdelayed=delayed,60,*",
                "CDEF:ddelayed=delayed,UN,0,delayed,IF,$step,*",
                "CDEF:sdelayed=PREV,UN,ddelayed,PREV,IF,ddelayed,+",
                "CDEF:rmdelayed=mdelayed,60,*",
                "LINE2:rdelayed#$color{delayed}:Delayed   ",
                'GPRINT:sdelayed:MAX:total\: %8.0lf msgs',
                'GPRINT:rdelayed:AVERAGE:avg\: %5.2lf msgs/min',
                'GPRINT:rmdelayed:MAX:max\: %4.0lf msgs/min\l',
        );
}

sub graph_imap($$)
{
        my ($range, $file) = @_;
        my $step = $range*$points_per_sample/$xpoints;
        rrd_graph($range, $file, $ypoints_imap,
                "DEF:imaploginall=$rrd_imap:imaploginall:AVERAGE",
                "DEF:mimaploginall=$rrd_imap:imaploginall:MAX",
                "CDEF:rimaploginall=imaploginall,60,*",
                "CDEF:rmimaploginall=mimaploginall,60,*",
                "CDEF:dimaploginall=imaploginall,UN,0,imaploginall,IF,$step,*",
                "CDEF:simaploginall=PREV,UN,dimaploginall,PREV,IF,dimaploginall,+",
                "AREA:rimaploginall#$color{imaploginall}:imap       ",
                'GPRINT:simaploginall:MAX:total\: %8.0lf logins',
                'GPRINT:rimaploginall:AVERAGE:avg\: %5.2lf logins/min',
                'GPRINT:rmimaploginall:MAX:max\: %4.0lf logins/min\l',

                "DEF:imaploginfailed=$rrd_imap:imaploginfailed:AVERAGE",
                "DEF:mimaploginfailed=$rrd_imap:imaploginfailed:MAX",
                "CDEF:rimaploginfailed=imaploginfailed,60,*",
                "CDEF:rmimaploginfailed=mimaploginfailed,60,*",
                "CDEF:dimaploginfailed=imaploginfailed,UN,0,imaploginfailed,IF,$step,*",
                "CDEF:simaploginfailed=PREV,UN,dimaploginfailed,PREV,IF,dimaploginfailed,+",
                "LINE2:rimaploginfailed#$color{imaploginfailed}:failed imap",
                'GPRINT:simaploginfailed:MAX:total\: %8.0lf logins',
                'GPRINT:rimaploginfailed:AVERAGE:avg\: %5.2lf logins/min',
                'GPRINT:rmimaploginfailed:MAX:max\: %4.0lf logins/min\l',
        );
}

sub usage
{
        print "usage: create_mailgraph_pics.pl [*options*]\n\n";
        print "  -h, --help         	display this help and exit\n";
        print "  -V, --version      	output version information and exit\n";
	print "  --imap-server		graph statistics for imap server\n";
	print "  --no-mail-graph	don't create mail graphs\n";
        print "  --no-virus-graph   	don't update the virus rrd\n";
        print "  --no-greylist-graph 	don't update the greylist rrd\n";
        print "  --no-imap-graph      	don't update the imap rrd\n";

        exit;
}

sub main()
{
	my $uri = 'pics';
	mkdir $tmp_dir, 0777 unless -d $tmp_dir;
	mkdir "$tmp_dir/$uri", 0777 unless -d "$tmp_dir/$uri";

		# create mailgraph pngs
                graph($graphs[0]{seconds}, "$tmp_dir/$uri/mailgraph_1d.png");
                graph($graphs[1]{seconds}, "$tmp_dir/$uri/mailgraph_7d.png");
                graph($graphs[2]{seconds}, "$tmp_dir/$uri/mailgraph_4w.png");
		graph($graphs[3]{seconds}, "$tmp_dir/$uri/mailgraph_6m.png");
                graph($graphs[4]{seconds}, "$tmp_dir/$uri/mailgraph_1y.png");

		# create mailgraph error pngs
		graph_err($graphs[0]{seconds}, "$tmp_dir/$uri/mailgraph_err_1d.png");
                graph_err($graphs[1]{seconds}, "$tmp_dir/$uri/mailgraph_err_7d.png");
                graph_err($graphs[2]{seconds}, "$tmp_dir/$uri/mailgraph_err_4w.png");
		graph_err($graphs[3]{seconds}, "$tmp_dir/$uri/mailgraph_err_6m.png");
                graph_err($graphs[4]{seconds}, "$tmp_dir/$uri/mailgraph_err_1y.png");
	
                # create mailgraph proto pngs
                graph_proto($graphs[0]{seconds}, "$tmp_dir/$uri/mailgraph_proto_1d.png");
                graph_proto($graphs[1]{seconds}, "$tmp_dir/$uri/mailgraph_proto_7d.png");
                graph_proto($graphs[2]{seconds}, "$tmp_dir/$uri/mailgraph_proto_4w.png");
		graph_proto($graphs[3]{seconds}, "$tmp_dir/$uri/mailgraph_proto_6m.png");
                graph_proto($graphs[4]{seconds}, "$tmp_dir/$uri/mailgraph_proto_1y.png");

		# create mailgraph queue pngs
		graph_queue($graphs[0]{seconds}, "$tmp_dir/$uri/mailgraph_queue_1d.png");
		graph_queue($graphs[1]{seconds}, "$tmp_dir/$uri/mailgraph_queue_7d.png");
		graph_queue($graphs[2]{seconds}, "$tmp_dir/$uri/mailgraph_queue_4w.png");
		graph_queue($graphs[3]{seconds}, "$tmp_dir/$uri/mailgraph_queue_6m.png");
		graph_queue($graphs[4]{seconds}, "$tmp_dir/$uri/mailgraph_queue_1y.png");

        	# create mailgraph greylist pngs
        	graph_grey($graphs[0]{seconds}, "$tmp_dir/$uri/mailgraph_grey_1d.png");
        	graph_grey($graphs[1]{seconds}, "$tmp_dir/$uri/mailgraph_grey_7d.png");
        	graph_grey($graphs[2]{seconds}, "$tmp_dir/$uri/mailgraph_grey_4w.png");
		graph_grey($graphs[3]{seconds}, "$tmp_dir/$uri/mailgraph_grey_6m.png");
        	graph_grey($graphs[4]{seconds}, "$tmp_dir/$uri/mailgraph_grey_1y.png");

                # create imap pngs
                graph_imap($graphs[0]{seconds}, "$tmp_dir/imapgraph_imap_1d.png");
                graph_imap($graphs[1]{seconds}, "$tmp_dir/imapgraph_imap_7d.png");
                graph_imap($graphs[2]{seconds}, "$tmp_dir/imapgraph_imap_4w.png");
		graph_imap($graphs[3]{seconds}, "$tmp_dir/imapgraph_imap_6m.png");
                graph_imap($graphs[4]{seconds}, "$tmp_dir/imapgraph_imap_1y.png");
}

main;
