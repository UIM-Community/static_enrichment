package Perluim::Core::Response;

use strict;
use warnings;

use Nimbus::API;
use Nimbus::PDS;

sub new {
    my ($class,$argRef) = @_;
    my $this = {
        _rc => $argRef->{rc},
        _id => $argRef->{id},
        _data => $argRef->{data},
        _time => $argRef->{time},
        _callback => $argRef->{callback},
        _retry => $argRef->{retry},
        _addr => defined $argRef->{addr} ? $argRef->{addr} : "undefined",
        _port => defined $argRef->{port} ? $argRef->{port} : "undefined",
        _robot => defined $argRef->{robot} ? $argRef->{robot} : "undefined", 
        _timeout => $argRef->{timeout}
    };
    return bless($this,ref($class) || $class);
}

sub rc {
    my ($self,$state) = @_;
    if(!defined $state) {
        return $self->{_rc};
    }
    return $self->{_rc} == $state ? 1 : 0;
}

sub getCallback() {
    my ($self) = @_;
    return $self->{_callback};
}

sub getID() {
    my ($self) = @_;
    return $self->{_id};
}

sub getTime() {
    my ($self) = @_;
    return $self->{_time};
}

sub getRetry() {
    my ($self) = @_;
    return $self->{_retry};
}

sub getAddr() {
    my ($self) = @_;
    return $self->{_addr};
}

sub getPort() {
    my ($self) = @_;
    return $self->{_port};
}

sub getRobot() {
    my ($self) = @_;
    return $self->{_robot};
}

sub getTimeout() {
    my ($self) = @_;
    return $self->{_timeout};
}

sub dump {
    my ($self) = @_;
    my @Dump = (
        rc          => $self->rc(),
        id          => $self->getID(),
        time        => $self->getTime(),
        callback    => $self->getCallback(),
        time        => $self->getTime(),
        retry       => $self->getRetry(),
        addr        => $self->getAddr(),
        port        => $self->getPort(),
        robot       => $self->getRobot(),
        timeout     => $self->getTimeout()
    );
    return \@Dump;
}

sub pdsData {
    my ($self) = @_;
    my $PDS = Nimbus::PDS->new($self->{_data});
    return $PDS;
}

sub hashData {
    my ($self) = @_;
    my $Hash = Nimbus::PDS->new($self->{_data})->asHash();
    return $Hash;
}

sub is {
    my ($self,$state) = @_;
    if(!defined $state) {
        $state = NIME_OK;
    }
    return $self->{_rc} == $state ? 1 : 0;
}

1;