package Perluim::API;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use vars qw(@ISA @EXPORT $AUTOLOAD);
require 5.010;
require Exporter;
require DynaLoader;
require AutoLoader;
use Scalar::Util qw(reftype looks_like_number);

use Nimbus::API;
use Nimbus::CFG;
use Nimbus::PDS;

use Perluim::Core::Request;
use Perluim::Core::Probe;
use Perluim::Logger;

our $Logger;
our $Debug = 0;
our $IDefaultRequest = {
    retry => 3,
    timeout => 5
};

@ISA = qw(Exporter DynaLoader);

@EXPORT = qw(
    uimRequest
    uimProbe
    uimLogger
    LogFATAL
    LogERROR
    LogWARN
    LogINFO
    LogDEBUG
    LogNOLEVEL
    LogSUCCESS
    toMilliseconds
    doSleep
    strBeginWith
    createDirectory
    terminalStdout
    getDate
    rndStr
    nimId
    generateAlarm
    pdsFromHash
    assignHash
    cleanDirectory
);
no warnings 'recursion';

use constant {
	LogFATAL    => 0,
	LogERROR    => 1,
	LogWARN     => 2,
	LogINFO	    => 3,
	LogDEBUG    => 4,
	LogNOLEVEL  => 5,
	LogSUCCESS  => 6
};

sub AUTOLOAD {
	no strict 'refs'; 
	
	my $sub = $AUTOLOAD;
    my $constname;
    ($constname = $sub) =~ s/.*:://;
	
	$!=0; 
    my ($val,$rc) = constant($constname, @_ ? $_[0] : 0);
    if ($rc != 0) {
		$AutoLoader::AUTOLOAD = $sub;
		goto &AutoLoader::AUTOLOAD;
    }
    *$sub = sub { $val };
    goto &$sub;
}

sub uimRequest {
    my ($argRef) = @_;
    return Perluim::Core::Request->new($argRef);
}

sub uimProbe {
    my ($argRef) = @_;
    my $probe = Perluim::Core::Probe->new($argRef);
    $probe->setLogger( $Logger ) if defined $Logger;
    return $probe;
}

sub uimLogger {
    my ($argRef) = @_;
    my $log = Perluim::Logger->new($argRef);
    if(!defined $Logger) {
        $Logger = $log;
    }
    return $log;
}

sub assignHash {
    my ($targetRef,$cibleRef,@othersRef) = @_;
    foreach my $key (keys %{ $cibleRef }) {
        if(!defined $targetRef->{$key}) {
            $targetRef->{$key} = $cibleRef->{$key};
        }
    }
    if(scalar @othersRef > 0) {
        foreach(@othersRef) {
            $targetRef = assignHash($targetRef,$_);
        }
    }
    return $targetRef;
}

sub toMilliseconds {
    my ($second) = @_; 
    return $second * 1000;
}

sub pdsFromHash {
    my ($hashRef) = @_;
    my $PDS = Nimbus::PDS->new;
    for my $key (keys %{ $hashRef }) {
        my $val = $hashRef->{$key};
        if(ref($val) eq "HASH") {
            $PDS->put($key,pdsFromHash($val),PDS_PDS);
        }
        else {
            $PDS->put($key,$val,looks_like_number($val) ? PDS_INT : PDS_PCH);
        }
    }
    return $PDS;
}

sub doSleep {
    my ($self,$sleepTime) = @_;
    $| = 1;
    while($sleepTime--) {
        sleep(1);
    }
}

sub cleanDirectory {
	my ($directory,$maxAge) = @_;

	opendir(DIR,"$directory");
	my @directory = readdir(DIR);
	my @toRemove = ();
	foreach my $file (@directory) {
		next if ($file =~ m/^\./);
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$directory/$file");
		if(defined $ctime) {
			push(@toRemove,$file) if(time() - $ctime > $maxAge);
		}
	}

	foreach(@toRemove) {
		$Logger->warn("Remove old directory $directory => $_") if defined $Logger;
		rmtree("$directory/$_");
	}
}

sub strBeginWith {
    return substr($_[0], 0, length($_[1])) eq $_[1];
}

sub createDirectory {
    my ($path) = @_;
    my @dir = split("/",$path);
    my $track = "";
    foreach(@dir) {
        my $path = $track.$_;
        if( !(-d $path) ) {
            mkdir($path) or die "Unable to create $_ directory!";
        }
        $track .= "$_/";
    }
}

sub terminalStdout {
    my $input;
    while(<>) {
        s/\s*$//;
        $input = $_;
        if(defined $input && $input ne "") {
            return $input;
        }
    }
}

sub getDate {
    my ($self) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $timestamp   = sprintf ( "%04d%02d%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
	$timestamp     =~ s/\s+/_/g;
	$timestamp     =~ s/://g;
    return $timestamp;
}

sub rndStr { 
    return join'', @_[ map{ rand @_ } 1 .. shift ] 
}

sub nimId {
    my $A = rndStr(10,'A'..'Z',0..9);
    my $B = rndStr(5,0..9);
    return "$A-$B";
}

sub generateAlarm {
    my ($subject,$hashRef) = @_;

    my $PDS = Nimbus::PDS->new(); 
    my $nimid = nimId();

    $PDS->string("nimid",$nimid);
    $PDS->number("nimts",time());
    $PDS->number("tz_offset",0);
    $PDS->string("subject",$subject);
    $PDS->string("md5sum","");
    $PDS->string("user_tag_1",$hashRef->{usertag1} || "");
    $PDS->string("user_tag_2",$hashRef->{usertag2} || "");
    $PDS->string("source",$hashRef->{source} || $hashRef->{robot} || "");
    $PDS->string("robot",$hashRef->{robot} || "");
    $PDS->string("prid",$hashRef->{probe} || "");
    $PDS->number("pri",$hashRef->{severity} || 0);
    $PDS->string("dev_id",$hashRef->{dev_id} || "");
    $PDS->string("met_id",$hashRef->{met_id} || "");
    if (defined $hashRef->{supp_key}) { 
        $PDS->string("supp_key",$hashRef->{supp_key}) 
    };
    $PDS->string("suppression",$hashRef->{suppression} || $hashRef->{supp_key} || "");
    $PDS->string("origin",$hashRef->{origin} || "");
    $PDS->string("domain",$hashRef->{domain} || "");

    my $AlarmPDS = Nimbus::PDS->new(); 
    $AlarmPDS->number("level",$hashRef->{severity} || 0);
    $AlarmPDS->string("message",$hashRef->{message});
    $AlarmPDS->string("subsys",$hashRef->{subsystem} || "1.1.");
    if(defined $hashRef->{token}) {
        $AlarmPDS->string("token",$hashRef->{token});
    }

    $PDS->put("udata",$AlarmPDS,PDS_PDS);

    return ($PDS,$nimid);
}    

1;