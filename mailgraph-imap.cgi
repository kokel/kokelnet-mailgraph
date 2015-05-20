#!/usr/bin/perl -w

# mailgraph -- an rrdtool frontend for mail statistics
# copyright (c) 2013 KokelNET
# copyright (c) 2013 Tobias Hachmer <network@kokelnet.de>
# copyright (c) 2000-2007 ETH Zurich
# copyright (c) 2000-2007 David Schweikert <david@schweikert.ch>
# released under the GNU General Public License

use RRDs;
use POSIX qw(uname);

my $VERSION = "0.1";

my $host = (POSIX::uname())[1];
my $company = 'KokelNET Mailgraph';
my $scriptname = 'mailgraph-imap.cgi';
my $xpoints = 540;
my $points_per_sample = 3;
my $ypoints = 160;
my $ypoints_imap = 160;
my $ypoints_pop3 = 160;
my $ypoints_proto = 96;
my $rrd = 'mailgraph.rrd'; # path to where the RRD database is
my $rrd_virus = 'mailgraph_virus.rrd'; # path to where the Virus RRD database is
my $rrd_imap = 'mailgraph_imap.rrd'; # path to where the Greylist RRD database is
my $tmp_dir = '/tmp/mailgraph-imap'; # temporary directory where to store the images

# note: the following ranges must match with the RRA ranges
# created in mailgraph.pl, otherwise the totals won't match.
my @graphs = (
	{ title => 'Last Day',   seconds => 3600*24,         },
	{ title => 'Last Week',  seconds => 3600*24*7,       },
	{ title => 'Last Month', seconds => 3600*24*31,      },
	{ title => 'Last 6 Months', seconds => 3600*24*31*6, },
	{ title => 'Last Year',  seconds => 3600*24*31*12,   },
);

my %color = (
	delivered 	=> '009900', # rrggbb in hex
	rejected 	=> 'AA0000', 
	bounced  	=> '000000',
        imaplogin       => '009900',
        imaplogintls    => '22C9BA',
        imaploginfailed => 'FF0000',
        pop3login       => 'FFBF00',
        pop3logintls    => 'FFFF00',
        pop3loginfailed => 'FF0000',
	ipv4login	=> '00FF00',
	ipv6login	=> '3399FF',
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

sub rrd_graph_imap(@)
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
		'--vertical-label', 'logins/min',
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
		"DEF:delivered=$rrd:delivered:AVERAGE",
		"DEF:mdelivered=$rrd:delivered:MAX",
		"CDEF:rdelivered=delivered,60,*",
		"CDEF:rmdelivered=mdelivered,60,*",
		"CDEF:ddelivered=delivered,UN,0,delivered,IF,$step,*",
		"CDEF:sdelivered=PREV,UN,ddelivered,PREV,IF,ddelivered,+",
		"AREA:rdelivered#$color{delivered}:Delivered",
		'GPRINT:sdelivered:MAX:total\: %8.0lf msgs',
		'GPRINT:rdelivered:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmdelivered:MAX:max\: %4.0lf msgs/min\l',

		"DEF:bounced=$rrd:bounced:AVERAGE",
		"DEF:mbounced=$rrd:bounced:MAX",
		"CDEF:rbounced=bounced,60,*",
		"CDEF:dbounced=bounced,UN,0,bounced,IF,$step,*",
		"CDEF:sbounced=PREV,UN,dbounced,PREV,IF,dbounced,+",
		"CDEF:rmbounced=mbounced,60,*",
		"LINE2:rbounced#$color{bounced}:Bounced  ",
		'GPRINT:sbounced:MAX:total\: %8.0lf msgs',
		'GPRINT:rbounced:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmbounced:MAX:max\: %4.0lf msgs/min\l',

		"DEF:rejected=$rrd:rejected:AVERAGE",
		"DEF:mrejected=$rrd:rejected:MAX",
		"CDEF:rrejected=rejected,60,*",
		"CDEF:drejected=rejected,UN,0,rejected,IF,$step,*",
		"CDEF:srejected=PREV,UN,drejected,PREV,IF,drejected,+",
		"CDEF:rmrejected=mrejected,60,*",
		"LINE2:rrejected#$color{rejected}:Rejected ",
		'GPRINT:srejected:MAX:total\: %8.0lf msgs',
		'GPRINT:rrejected:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmrejected:MAX:max\: %4.0lf msgs/min\l',


	);
}

sub graph_imap($$)
{
        my ($range, $file) = @_;
        my $step = $range*$points_per_sample/$xpoints;
        rrd_graph_imap($range, $file, $ypoints_imap,
                "DEF:imaplogintls=$rrd_imap:imaplogintls:AVERAGE",
                "DEF:mimaplogintls=$rrd_imap:imaplogintls:MAX",
                "CDEF:rimaplogintls=imaplogintls,60,*",
                "CDEF:rmimaplogintls=mimaplogintls,60,*",
                "CDEF:dimaplogintls=imaplogintls,UN,0,imaplogintls,IF,$step,*",
                "CDEF:simaplogintls=PREV,UN,dimaplogintls,PREV,IF,dimaplogintls,+",
                "AREA:rimaplogintls#$color{imaplogintls}:IMAP/TLS   ",
                'GPRINT:simaplogintls:MAX:total\: %8.0lf logins',
                'GPRINT:rimaplogintls:AVERAGE:avg\: %5.2lf logins/min',
                'GPRINT:rmimaplogintls:MAX:max\: %4.0lf logins/min\l',

                "DEF:imaplogin=$rrd_imap:imaplogin:AVERAGE",
                "DEF:mimaplogin=$rrd_imap:imaplogin:MAX",
                "CDEF:rimaplogin=imaplogin,60,*",
                "CDEF:rmimaplogin=mimaplogin,60,*",
                "CDEF:dimaplogin=imaplogin,UN,0,imaplogin,IF,$step,*",
                "CDEF:simaplogin=PREV,UN,dimaplogin,PREV,IF,dimaplogin,+",
                "LINE2:rimaplogin#$color{imaplogin}:IMAP       ",
                'GPRINT:simaplogin:MAX:total\: %8.0lf logins',
                'GPRINT:rimaplogin:AVERAGE:avg\: %5.2lf logins/min',
                'GPRINT:rmimaplogin:MAX:max\: %4.0lf logins/min\l',

                "DEF:imaploginfailed=$rrd_imap:imaploginfailed:AVERAGE",
                "DEF:mimaploginfailed=$rrd_imap:imaploginfailed:MAX",
                "CDEF:rimaploginfailed=imaploginfailed,60,*",
                "CDEF:rmimaploginfailed=mimaploginfailed,60,*",
                "CDEF:dimaploginfailed=imaploginfailed,UN,0,imaploginfailed,IF,$step,*",
                "CDEF:simaploginfailed=PREV,UN,dimaploginfailed,PREV,IF,dimaploginfailed,+",
                "LINE2:rimaploginfailed#$color{imaploginfailed}:Failed IMAP",
                'GPRINT:simaploginfailed:MAX:total\: %8.0lf logins',
                'GPRINT:rimaploginfailed:AVERAGE:avg\: %5.2lf logins/min',
                'GPRINT:rmimaploginfailed:MAX:max\: %4.0lf logins/min\l',
        );
}


sub graph_pop3($$)
{
        my ($range, $file) = @_;
        my $step = $range*$points_per_sample/$xpoints;
        rrd_graph_imap($range, $file, $ypoints_pop3,
                "DEF:pop3logintls=$rrd_imap:pop3logintls:AVERAGE",
                "DEF:mpop3logintls=$rrd_imap:pop3logintls:MAX",
                "CDEF:rpop3logintls=pop3logintls,60,*",
                "CDEF:rmpop3logintls=mpop3logintls,60,*",
                "CDEF:dpop3logintls=pop3logintls,UN,0,pop3logintls,IF,$step,*",
                "CDEF:spop3logintls=PREV,UN,dpop3logintls,PREV,IF,dpop3logintls,+",
                "AREA:rpop3logintls#$color{pop3logintls}:POP3/TLS   ",
                'GPRINT:spop3logintls:MAX:total\: %8.0lf logins',
                'GPRINT:rpop3logintls:AVERAGE:avg\: %5.2lf logins/min',
                'GPRINT:rmpop3logintls:MAX:max\: %4.0lf logins/min\l',

                "DEF:pop3login=$rrd_imap:pop3login:AVERAGE",
                "DEF:mpop3login=$rrd_imap:pop3login:MAX",
                "CDEF:rpop3login=pop3login,60,*",
                "CDEF:rmpop3login=mpop3login,60,*",
                "CDEF:dpop3login=pop3login,UN,0,pop3login,IF,$step,*",
                "CDEF:spop3login=PREV,UN,dpop3login,PREV,IF,dpop3login,+",
                "LINE2:rpop3login#$color{pop3login}:POP3       ",
                'GPRINT:spop3login:MAX:total\: %8.0lf logins',
                'GPRINT:rpop3login:AVERAGE:avg\: %5.2lf logins/min',
                'GPRINT:rmpop3login:MAX:max\: %4.0lf logins/min\l',

                "DEF:pop3loginfailed=$rrd_imap:pop3loginfailed:AVERAGE",
                "DEF:mpop3loginfailed=$rrd_imap:pop3loginfailed:MAX",
                "CDEF:rpop3loginfailed=pop3loginfailed,60,*",
                "CDEF:rmpop3loginfailed=mpop3loginfailed,60,*",
                "CDEF:dpop3loginfailed=pop3loginfailed,UN,0,pop3loginfailed,IF,$step,*",
                "CDEF:spop3loginfailed=PREV,UN,dpop3loginfailed,PREV,IF,dpop3loginfailed,+",
                "LINE2:rpop3loginfailed#$color{pop3loginfailed}:Failed POP3",
                'GPRINT:spop3loginfailed:MAX:total\: %8.0lf logins',
                'GPRINT:rpop3loginfailed:AVERAGE:avg\: %5.2lf logins/min',
                'GPRINT:rmpop3loginfailed:MAX:max\: %4.0lf logins/min\l',
        );
}

sub graph_proto($$)
{
	my ($range, $file) = @_;
	my $step = $range*$points_per_sample/$xpoints;
	rrd_graph_imap($range, $file, $ypoints_proto,
		"DEF:ipv4login=$rrd_imap:ipv4login:AVERAGE",
		"DEF:mipv4login=$rrd_imap:ipv4login:MAX",
		"CDEF:ripv4login=ipv4login,60,*",
		"CDEF:rmipv4login=mipv4login,60,*",
		"CDEF:dipv4login=ipv4login,UN,0,ipv4login,IF,$step,*",
		"CDEF:sipv4login=PREV,UN,dipv4login,PREV,IF,dipv4login,+",
		"LINE2:ripv4login#$color{ipv4login}:IPv4 Logins",
		'GPRINT:sipv4login:MAX:total\: %8.0lf msgs',
		'GPRINT:ripv4login:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmipv4login:MAX:max\: %4.0lf msgs/min\l',

		"DEF:ipv6login=$rrd_imap:ipv6login:AVERAGE",
		"DEF:mipv6login=$rrd_imap:ipv6login:MAX",
		"CDEF:ripv6login=ipv6login,60,*",
		"CDEF:rmipv6login=mipv6login,60,*",
		"CDEF:dipv6login=ipv6login,UN,0,ipv6login,IF,$step,*",
		"CDEF:sipv6login=PREV,UN,dipv6login,PREV,IF,dipv6login,+",
		"LINE2:ripv6login#$color{ipv6login}:IPv6 Logins",
		'GPRINT:sipv6login:MAX:total\: %8.0lf msgs',
		'GPRINT:ripv6login:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmipv6login:MAX:max\: %4.0lf msgs/min\l',
	);
}

sub print_html()
{
	print "Content-Type: text/html\n\n";

	print <<HEADER;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Mail statistics for $host</title>
<meta http-equiv="Refresh" content="300" />
<meta http-equiv="Pragma" content="no-cache" />
<link rel="stylesheet" href="mailgraph.css" type="text/css" />
</head>
<body>
HEADER

	print "<h1>Mail statistics for $host</h1>\n";

	print "<ul id=\"jump\">\n";
	for my $n (0..$#graphs) {
		print "  <li><a href=\"#G$n\">$graphs[$n]{title}</a>&nbsp;</li>\n";
	}
	print "</ul>\n";

	for my $n (0..$#graphs) {
		print "<h2 id=\"G$n\">$graphs[$n]{title}</h2>\n";
		print "<p><img src=\"$scriptname?${n}-n\" alt=\"mailgraph\"/><br/>\n";
		print "<img src=\"$scriptname?${n}-i\" alt=\"mailgraph\"/></p>\n";
		print "<img src=\"$scriptname?${n}-f\" alt=\"mailgraph\"/></p>\n";
		print "<img src=\"$scriptname?${n}-p\" alt=\"mailgraph\"/></p>\n";
	}

	print <<FOOTER;
<hr/>
<table><tr><td>
<a href="https://github.com/kokel/kokelnet-mailgraph">KokelNET Mailgraph</a> $VERSION
by <a href="mailto:network\@kokelnet.de">Tobias Hachmer</a></td>
<td align="right">
<a href="https://oss.oetiker.ch/rrdtool/"><img src="https://oss.oetiker.ch/rrdtool/.pics/rrdtool.gif" alt="" width="120" height="34"/></a>
</td></tr>
<tr><td>
Based upon <a href="https://mailgraph.schweikert.ch/">Mailgraph</a>
by <a href="https://david.schweikert.ch/">David Schweikert</a></td>
</td></tr>
</table>
</body></html>
FOOTER
}

sub send_image($)
{
	my ($file)= @_;

	-r $file or do {
		print "Content-type: text/plain\n\nERROR: can't find $file\n";
		exit 1;
	};

	print "Content-type: image/png\n\n";
	print "Content-length: ".((stat($file))[7])."\n" unless $ARGV[0];
	print "\n" unless $ARGV[0];
	open(IMG, $file) or die;
	my $data;
	print $data while read(IMG, $data, 16384)>0;
}

sub main()
{
	my $uri = $ENV{REQUEST_URI} || '';
	$uri =~ s/\/[^\/]+$//;
	$uri =~ s/\//,/g;
	$uri =~ s/(\~|\%7E)/tilde,/g;
	mkdir $tmp_dir, 0777 unless -d $tmp_dir;
	mkdir "$tmp_dir/$uri", 0777 unless -d "$tmp_dir/$uri";

	my $img = $ARGV[0] || $ENV{QUERY_STRING};
	if(defined $img and $img =~ /\S/) {
		if($img =~ /^(\d+)-n$/) {
			my $file = "$tmp_dir/$uri/mailgraph_$1.png";
			graph($graphs[$1]{seconds}, $file);
			send_image($file);
		}
		elsif($img =~ /^(\d+)-i$/) {
			my $file = "$tmp_dir/$uri/mailgraph_$1_imap.png";
			graph_imap($graphs[$1]{seconds}, $file);
			send_image($file);
		}
		elsif($img =~ /^(\d+)-f$/) {
			my $file = "$tmp_dir/$uri/mailgraph_$1_pop3.png";
			graph_pop3($graphs[$1]{seconds}, $file);
			send_image($file);
		}
		elsif($img =~ /^(\d+)-p$/) {
			my $file = "$tmp_dir/$uri/mailgraph_$1_proto.png";
			graph_proto($graphs[$1]{seconds}, $file);
			send_image($file);
		}
		else {
			die "ERROR: invalid argument\n";
		}
	}
	else {
		print_html;
	}
}

main;

