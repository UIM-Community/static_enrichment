package Perluim::Addons::ARGMap;

sub new {
    my ($class,@argv,$allowMultiple) = @_;
    my %Hash = ();
    my $this = {
        argv => \@argv,
        _inner => \%Hash,
        allowMultiple => defined $allowMultiple ? $allowMultiple : 1
    };
    return bless($this,ref($class) || $class);
}

sub set {
    my($self,$key,$identifier) = @_;
    if(not defined $identifier) {
        $identifier = $key;
    }
    my $count = 0;
    my @argArr = @{ $self->{argv} };
    foreach(@argArr) {
        if($_ eq $key) {
            my $val = $argArr[$count + 1] || "noArg";
            my @mulVal = split(",",$val); 
            if(scalar @mulVal > 1 && $self->{allowMultiple} == 1) {
                $self->{_inner}->{$identifier} = @mulVal;
            }
            else {
                $self->{_inner}->{$identifier} = $val;
            }
        }
        $count++;
    }
}

sub has {
    my ($self,$arg) = @_;
    if(exists $self->{_inner}->{$arg}) {
        return 1;
    }
    return 0;
}

sub get {
    my ($self,$identifier) = @_; 
    return $self->{_inner}->{$identifier};
}

1;