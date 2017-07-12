package Lib::enrichment_rule;
use Data::Dumper;
$Data::Dumper::Deparse = 1;

our $Logger;

sub new {
    my ($class,$this) = @_;
    return bless($this,ref($class) || $class);
}

sub isMatch {
    my ($self,$value) = @_;
    return $value =~ $self->{regexp} ? 1 : 0;
}

sub getField {
    my ($self) = @_;
    return $self->{field};
}

sub getOverwritedValue {
    my ($self,$key,$PDSRef) = @_;
    my $Str = $self->{overwrite}->{$key};
    my @matches = ( $Str =~ /\[([A-Za-z0-9\._]+)\]/g );
    foreach (@matches) {
        my @keyElems    = split(/\./,"$_");
        my $elemRef     = $PDSRef;
        foreach(@keyElems) {
            if(!defined $elemRef->{$_}) {
                $elemRef = "";
                last;
            }
            $elemRef = $elemRef->{$_};
        }
        my $replace = ${ elemRef };
        $Str =~ s/\[$_\]/$replace/g;
    }
    return $Str;
}

sub processAlarm {
    my ($self,$PDSRef) = @_;
    my @fieldArr    = split(/\./,"$self->{field}");
    my $fieldValue  = $PDSRef;
    foreach(@fieldArr) {
        return $PDSRef,0 if !defined $fieldValue->{$_};
        $fieldValue = $fieldValue->{$_};
    }
    undef @fieldArr;
    return $PDSRef,0 if !$self->isMatch(${fieldValue});

    $Logger->log(1,"$self->{name}:: Processing enrichment on $PDSRef->{nimid}");
    for my $key (keys %{ $self->{overwrite} }) {
        my @keyElems    = split(/\./,"$key");
        my $elemRef     = $PDSRef;
        foreach(@keyElems) {
            if(!defined $elemRef->{$_}) {
                $elemRef->{$_} = $self->getOverwritedValue($key,$PDSRef);
            }
            $elemRef = $elemRef->{$_};
        }
    }
    return $PDSRef,1;
}

1;