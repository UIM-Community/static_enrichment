package Perluim::Addons::FSMap;

use strict;
use warnings;
use Perluim::Utils;
use Nimbus::API;
use Nimbus::PDS;
use Nimbus::CFG;

sub new {
    my ($class,$location) = @_;
    my %Hash = ();
    my $this = {
        location => $location,
        sections => \%Hash
    };
    if(index($location,'.cfg') == -1) {
        die "Invalid manifest file $location";
    }
    if(not -f $location) {
        open my $fh, '>', "$location";
        close $fh;
    }
    $this->{file} = cfgOpen($location,0);
    my ($list) = cfgSectionList($this->{file});
    foreach(@$list) {
        $this->{sections}->{$_} = 1;
    }
    my $blessed = bless($this,ref($class) || $class);
    return $blessed;
}

sub begins_with {
    return substr($_[0], 0, length($_[1])) eq $_[1];
}

sub has {
    my ($self,$key) = @_;
    if(not perluim::utils::strBeginWith($key,'/')) {
        $key = "/$key";
    }
    if(defined $self->{sections}->{$key}) {
        return 1;
    }
    return 0;
}

sub getParams {
    my ($self,$key) = @_;
    if(not perluim::utils::strBeginWith($key,'/')) {
        $key = "/$key";
    }
    my ($list) = cfgKeyList($self->{file},$key);
    my %HashRef = ();
    foreach(@$list) {
        $HashRef{$_} = cfgKeyRead($self->{file},$key,$_);
    }
    return \%HashRef;
}

sub set {
    my ($self,$key,$hashRefParams) = @_;
    if(not perluim::utils::strBeginWith($key,'/')) {
        $key = "/$key";
    }
    if($self->has($key)) {
        if(defined $hashRefParams) {
            my %Hash = %$hashRefParams;
            foreach(keys %Hash) {
                cfgKeyDelete($self->{file},$key,$_);
                cfgKeyWrite($self->{file},$key,$_,$Hash{$_});
            }
        }
    }
    else {
        cfgKeyWrite($self->{file},$key,$key,'');
        cfgKeyDelete($self->{file},$key,$key);
        if(defined $hashRefParams) {
            my %Hash = %$hashRefParams;
            foreach(keys %Hash) {
                cfgKeyWrite($self->{file},$key,$_,$Hash{$_});
            }
        }
    }
}

sub delete {
    my ($self,$key) = @_;
    if(not perluim::utils::strBeginWith($key,'/')) {
        $key = "/$key";
    }
    cfgSectionDelete($self->{file},$key);
}

sub writeToDisk {
    my ($self) = @_;
    cfgSync($self->{file});
}

1;