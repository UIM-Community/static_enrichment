package Perluim::Core::Events;

sub new {
    my ($class) = @_;
    my $this = {
        subscribers => {}
    };
    return bless($this,ref($class) || $class);
}

sub on {
    my ($self,$eventName,$callbackRef) = @_;
    $self->register_suscriber($eventName,$callbackRef,0);
}

sub once {
    my ($self,$eventName,$callbackRef) = @_; 
    $self->register_suscriber($eventName,$callbackRef,1);
}

sub emit {
    my ($self,$eventName,$data) = @_;
    $self->_exec($eventName,$data) if $self->has_subscriber($eventName);
}

sub _exec {
    my ($self,$subscriberName,$data) = @_; 
    foreach my $ref (@{ $self->{subscribers}->{$subscriberName} }) {
        $ref->{cb}->($data);
        $self->remove_subscriber($subscriberName) if $ref->{mu} == 1;
    }
}

sub register_suscriber {
    my ($self,$eventName,$callbackRef,$unique) = @_;
    my $iRef = {
        cb => $callbackRef,
        mu => $unique
    };
    if($self->has_subscriber($eventName)) {
        push(@{ $self->{subscribers}->{$eventName} },$iRef);
    }
    else {
        my @Arr = ($iRef);
        $self->{subscribers}->{$eventName} = \@Arr;
    }
}

sub has_subscriber {
    my ($self,$subscriberName) = @_;
    return defined $self->{subscribers}->{$subscriberName} ? 1 : 0;
}

sub remove_subscriber {
    my ($self,$subscriberName) = @_;
    if($self->has_subscriber($subscriberName)) {
        $self->{subscribers}->{$subscriberName} = undef;
    }
}

1;