package Plack::Middleware::SocketIO::Handle;

use strict;
use warnings;

use AnyEvent::Handle;

sub new {
    my $class = shift;
    my ($fh) = @_;

    my $self = {handle => AnyEvent::Handle->new(fh => $fh)};
    bless $self, $class;

    $fh->autoflush;

    $self->{handle}->no_delay(1);
    $self->{handle}->on_eof(sub   { warn "Unhandled handle eof" });
    $self->{handle}->on_error(sub { warn "Unhandled handle error: $_[2]" });

    # This is needed for the correct EOF handling
    $self->{handle}->on_read(sub { });

    return $self;
}

sub heartbeat_timeout {
    my $self = shift;
    my ($timeout) = @_;

    $self->{heartbeat_timeout} = $timeout;

    return $self;
}

sub on_heartbeat {
    my $self = shift;
    my ($cb) = @_;

    $self->{handle}->timeout($self->{heartbeat_timeout});
    $self->{handle}->on_timeout($cb);

    return $self;
}

sub on_read {
    my $self = shift;
    my ($cb) = @_;

    $self->{handle}->on_read(
        sub {
            my $handle = shift;

            $handle->push_read(
                sub {
                    $cb->($self, $_[0]->rbuf);
                }
            );
        }
    );

    return $self;
}

sub on_eof {
    my $self = shift;
    my ($cb) = @_;

    $self->{handle}->on_eof(
        sub {
            $cb->($self);
        }
    );

    return $self;
}

sub on_error {
    my $self = shift;
    my ($cb) = @_;

    $self->{handle}->on_error(
        sub {
            $cb->($self);
        }
    );

    return $self;
}

sub write {
    my $self = shift;
    my ($chunk, $cb) = @_;

    my $handle = $self->{handle};
    return $self unless $handle;

    $handle->push_write($chunk);

    if ($cb) {
        $handle->on_drain(
            sub {
                $self->{handle}->on_drain(undef);

                $cb->($self);
            }
        );
    }

    return $self;
}

sub close {
    my $self = shift;

    my $handle = delete $self->{handle};
    return $self unless $handle;

    $handle->timeout_reset;

    shutdown $handle->fh, 2;
    close $handle->fh;

    $handle->destroy;
    undef $handle;

    return $self;
}

1;
__END__

=head1 NAME

Plack::Middleware::SocketIO::Handle - Handle

=head1 DESCRIPTION

L<Plack::Middleware::SocketIO::Handle> is a wrapper on top of
L<AnyEvent::Handle>.

=head1 METHODS

=head2 C<new>

=head2 C<heartbeat_timeout>

=head2 C<on_eof>

=head2 C<on_heartbeat>

=head2 C<on_read>

=head2 C<write>

=head2 C<close>

=head1 SEE ALSO

L<AnyEvent::Handle>

=cut
