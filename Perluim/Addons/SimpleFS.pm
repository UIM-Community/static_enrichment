package Perluim::Addons::SimpleFS;

use strict;
use warnings;

sub new {
    my ($class,$fileName) = @_;
    my $this = {
        fileName => $fileName || undef,
        content => undef
    };
    return bless($this,ref($class) || $class);
}

sub load {
    my ($self,$fileName) = @_;
    if(open(my $list, '<:encoding(UTF-8)',$self->{fileName} || $fileName)) {
        my @Rows = ();
        while(my $row = <$list>) {
            $row =~ s/^\s+|\s+$//g;
            push(@Rows,$row);
        }
        $self->{content} = @Rows;
        return 1,@Rows;
    }
    else {
        return 0,undef;
    }
}

sub loadString {
    my ($self,$fileName) = @_;
    if(open(my $list, '<:encoding(UTF-8)',$self->{fileName} || $fileName)) {
        my $Str = "";
        while(my $row = <$list>) {
            $row =~ s/^\s+|\s+$//g;
            $Str .= $row;
        }
        return 1,$Str;
    }
    else {
        return 0,undef;
    }
}

sub save {
    my ($self,$output,$Array,$ObjectKey) = @_;
    if(defined($Array)) {
        my $file_handler;
        unless(open($file_handler,">", "$output")) {
            warn "Unabled to open rejected_files \n";
            return;
        }
        if(defined $ObjectKey) {
            foreach(@{ $Array }) {
                print $file_handler "$_->{$ObjectKey}\n";
            }
        }
        else {
            foreach(@{ $Array }) {
                print $file_handler "$_\n";
            }
        }
        close $file_handler;
    }
    else {
        my $file_handler;
        unless(open($file_handler,">", "$output")) {
            warn "Unabled to open rejected_files \n";
            return;
        }
        foreach(@{ $self->{content} }) {
            print $file_handler "$_\n";
        }
        close $file_handler;
    }
}

1;