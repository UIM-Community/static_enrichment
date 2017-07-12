package Perluim::Logger;

use strict;
use warnings;

use File::Copy;
use Nimbus::API;
use IO::Handle;
use Scalar::Util qw(looks_like_number);

# LOGLEVEL Header
our %loglevel = (
	0 => "[CRITICAL]",
	1 => "[INFO]    ",
	2 => "[INFO]    ",
	3 => "[INFO]    ",
	4 => "[DEBUG]   ",
	5 => "          "
);

sub new {
    my ($class,$opt) = @_;
    my $this = {
        file 	=> $opt->{file},
        level 	=> defined $opt->{level} 	? $opt->{level} : 3,
        size 	=> defined $opt->{size} 	? $opt->{size} * 1024 : 0,
		_header => "",
		closed  => 0,
        startTime => time()
    };
    my $blessed = bless($this,ref($class) || $class);
    nimLogSet($blessed->{file},"",$blessed->{level},NIM_LOGF_NOTRUNC);
	nimLogTruncateSize($blessed->{size}) if $blessed->{size} != 0;
	return $blessed;
}

#
# set log level
#
sub setLevel {
	my ($self,$level) = @_; 
    nimLogSetLevel($level) if defined $level && looks_like_number($level);
}

#
# set log size.
#
sub setSize {
    my ($self,$size) = @_;
    nimLogTruncateSize($size * 1024) if defined $size;
}

#
# set log header (log prefix)
#
sub setHeader {
	my ($self,$headerStr,$reset) = @_;
	return if !defined $headerStr;
	$reset = defined $reset ? $reset : 1;
	if($reset) {
		$self->{_header} = $headerStr;
		return;
	}
	$self->{_header} .= $headerStr;
}

#
# reset header
#
sub resetHeader {
	my ($self) = @_;
	$self->{_header} = "";
}

#
# get a formatted date (on system datetime).
#
sub getFormattedDate {
	my @months  = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	my @days    = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $timetwoDigits = sprintf("%02d %02d:%02d:%02d",$mday,$hour,$min,$sec);
	return "$months[$mon] $timetwoDigits";
}

#
# Trace log from another emitter!
#
sub trace {
    my($self,$emitter) = @_;
    return if !defined $emitter;
    $emitter->on(log => sub {
        $self->info(shift);
    });
}

#
# Catch error from another emitter!
#
sub catch {
	my($self,$emitter) = @_;
    return if !defined $emitter;
    $emitter->on(error => sub {
        $self->error(shift);
    });
}

# 
# Truncate log file!
# 
sub truncate {
    my ($self) = @_;
    nimLogTruncate();
}

#
# close log!
#
sub close {
	my ($self) = @_;
	$self->{closed} = 1;
	nimLogClose();
}

#
# copyTo a new destination!
#
sub copyTo {
	my ($self,$path) = @_;
    return if !defined $path;
	$self->close();
	copy("$self->{file}","$path/$self->{file}") or warn "Failed to copy logfile $self->{file} to $path!";
}

#
# All logs routines
#
sub log {
    my ($self,$level,$msg) = @_; 
	return if $self->{closed};
    if(!defined($level)) {
        $level = 3;
    }
    my $date 		= getFormattedDate();
    my $header 		= $self->{_header};
    nimLog($level,"$date $loglevel{$level} - ${header}${msg}");
	print "$date $loglevel{$level} - ${header}${msg}\n";
}

sub fatal {
	my ($self,$msg) = @_;
	$self->log(0,$msg);
}

sub error {
	my ($self,$msg) = @_;
	$self->log(1,$msg);
}

sub warn {
	my ($self,$msg) = @_;
	$self->log(2,$msg);
}

sub info {
	my ($self,$msg) = @_;
	$self->log(3,$msg);
}

sub debug {
	my ($self,$msg) = @_;
	$self->log(4,$msg);
}

sub nolevel {
	my ($self,$msg) = @_;
	$self->log(5,$msg);
}