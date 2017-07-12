package Perluim::Core::Request;

use strict;
use warnings;

use Nimbus::API;
use Nimbus::PDS;
use Perluim::Core::Events;
use Perluim::Core::Response;
use Scalar::Util qw(reftype looks_like_number);

our %nimport_map = (
    48000 => "controller",
    48001 => "spooler",
    48002 => "hub"
);

sub new {
    my ($class,$argRef) = @_;
    if(defined $argRef->{addr} && not defined $argRef->{robot}) {
        my @addrArray = split("/",$argRef->{addr});
        if(scalar @addrArray >= 3) {
            $argRef->{robot} = $addrArray[2];
        }
    }
    my $this = {
        robot   => $argRef->{robot},
        addr    => $argRef->{addr},
        port    => defined $argRef->{port} ? $argRef->{port} : 48000,
        callback => defined $argRef->{callback} ? $argRef->{callback} : "get_info",
        retry   => defined $argRef->{retry} ? $argRef->{retry} : 1,
        timeout => defined $argRef->{timeout} ? $argRef->{timeout} : 5,
        Emitter => Perluim::Core::Events->new
    };
    return bless($this,ref($class) || $class);
}

sub emit {
    my ($self,$eventName,$data) = @_;
    $self->{Emitter}->emit($eventName,$data);
}

sub on {
    my ($self,$eventName,$callbackRef) = @_;
    $self->{Emitter}->on($eventName,$callbackRef);
}

sub setInfo {
    my ($self,$addr,$callback) = @_;
    $self->{addr} = $addr;
    $self->{callback} = $callback;
}

sub setTimeout {
    my ($self,$timeOut) = @_;
    if(defined $timeOut) {
        $self->{timeout} = $timeOut;
        return 1;
    }
    return 0;
}

sub setRetry {
    my ($self,$retryInt) = @_;
    if(defined $retryInt) {
        $self->{retry} = $retryInt;
        return 1;
    }
    return 0;
}

sub _pdsFromHash {
    my ($self,$PDSData) = @_;
    my $PDS = Nimbus::PDS->new;
    for my $key (keys %{ $PDSData }) {
        my $val = $PDSData->{$key};
        if(ref($val) eq "HASH") {
            $PDS->put($key,$val,PDS_PDS);
        }
        else {
            $PDS->put($key,$val,looks_like_number($val) ? PDS_INT : PDS_PCH);
        }
    }
    return $PDS;
}

sub _rndStr { 
    my @chars = ("a".."z");
    my $string;
    $string .= $chars[rand @chars] for 1..10;
    return $string;
}

sub send {
    my ($self,$callRef,$PDSData) = @_;
    my ($overbus,$timeout,$callback,$addr,$port,$robot,$retry,$Ret,$PDS);
    my $i           = 0;
    my $RC          = NIME_ERROR;
    my $t_start     = time;

    my $request_id  = $self->_rndStr();
    my $header      = "[req::$request_id]";

    # Define variables
    if(ref($callRef) eq "HASH") {
        $overbus    = defined $callRef->{overbus} ? $callRef->{overbus} : 1;
        $retry      = defined $callRef->{_retry} ? $callRef->{_retry} : $self->{retry};
        $timeout    = defined $callRef->{_timeout} ? $callRef->{_timeout} : $self->{timeout};
        $callback   = defined $callRef->{_callback} ? $callRef->{_callback} : $self->{callback};
        $addr       = defined $callRef->{_addr} ? $callRef->{_addr} : $self->{addr};
        $robot      = defined $callRef->{_robot} ? $callRef->{_robot} : $self->{robot};
        $port       = defined $callRef->{_port} ? $callRef->{_port} : $self->{port};
    }
    else {
        $overbus    = $callRef; 
        $timeout    = $self->{timeout};
        $retry      = $self->{retry};
        $callback   = $self->{callback};
        $addr       = $self->{addr};
        $robot      = $self->{robot};
        $port       = $self->{port};
    }
    
    # Hydrate PDS
    $PDS = ref($PDSData) eq "HASH" ? $self->_pdsFromHash($PDSData) : (defined $PDSData ? $PDSData : Nimbus::PDS->new);

    $self->emit('log',"$header New request sent to Nimbus");
    $| = 1; # Flush I/O

    if($overbus && defined $addr) {
        $self->emit('log',"$header nimNamedRequest triggered");
        for(;$i < $retry;$i++) {
            eval {
                local $SIG{ALRM} = sub { 
                    die "alarm\n";
                }; 
                alarm $timeout;
                ($RC,$Ret) = nimNamedRequest(
                    $addr,
                    $callback,
                    $PDS->data
                );
                alarm 0;
            };
            if ($@) {
                $RC = NIME_EXPIRED;
                $self->emit('log',"$header nimNamedRequest timeout");
                die unless $@ eq "alarm\n";   # propagate unexpected errors
            }

            $self->emit('log',"$header terminated with RC => $RC");
            last if $RC == NIME_OK;

            $self->emit('error',nimError2Txt($RC));
            last if $RC != NIME_COMERR && $RC != NIME_ERROR;

            sleep(1);
        }
    }
    elsif(defined $port && ( defined $robot || defined $nimport_map{ $port } ) ) {
        $self->emit('log',"$header nimRequest triggered");
        for(;$i < $retry;$i++) {
            $robot = defined $robot ? $robot : $nimport_map{ $port };
            eval {
                local $SIG{ALRM} = sub { 
                    die "alarm\n";
                }; 
                alarm $timeout;
                ($RC,$Ret) = nimRequest(
                    $robot,
                    $port,
                    $callback,
                    $PDS->data
                );
                alarm 0;
            };
            if ($@) {
                $RC = NIME_EXPIRED;
                $self->emit('log',"$header nimRequest timeout");
                die unless $@ eq "alarm\n";   # propagate unexpected errors
            }

            $self->emit('log',"$header terminated with RC => $RC");
            last if $RC == NIME_OK;

            $self->emit('error',nimError2Txt($RC));
            last if $RC != NIME_COMERR && $RC != NIME_ERROR;

            sleep(1);
        }
    }
    else {
        $self->emit('error',"$header missing request data to launch a new request!");
    }

    my $response = Perluim::Core::Response->new({
        rc => $RC,
        id => $request_id,
        data => $Ret,
        time => $t_start - time,
        retry => $i,
        timeout => $timeout,
        addr => $addr,
        robot => $robot,
        port => $port,
        callback => $callback
    });
    $self->emit('done',$response);
    return $response;
}

1;