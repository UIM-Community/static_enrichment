package Lib::enrichment_rule;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

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
            my $value = looks_like_number($_) ? $elemRef->[$_] : $elemRef->{$_};
            if(not defined $value) {
                $elemRef = $self->{fallbackValue} || "";
                last;
            }
            $elemRef = $value;
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
        return $PDSRef,0,0 unless defined $fieldValue->{$_};
        $fieldValue = $fieldValue->{$_};
    }
    undef @fieldArr;

    return $PDSRef,0,0 unless $self->isMatch(${fieldValue});
    return $PDSRef,0,1 if $self->{drop} == 1;

    $Logger->log(1,"$self->{name}:: Processing enrichment on $PDSRef->{nimid}");
    for my $key (keys %{ $self->{overwrite} }) {
        my @keyElems    = split(/\./,"$key");
        my $elemRef     = $PDSRef;

        foreach(@keyElems) {
            if($_ ne "udata") {
                $elemRef->{$_} = $self->getOverwritedValue($key,$PDSRef);
            }
            $elemRef = $elemRef->{$_};
        }
    }

    return $PDSRef,1,0;
}

1;
