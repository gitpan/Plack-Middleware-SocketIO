package Plack::Middleware::SocketIO::WebSocket;

use strict;
use warnings;

use base 'Plack::Middleware::SocketIO::Base';

use Protocol::WebSocket::Frame;
use Protocol::WebSocket::Handshake::Server;

use Plack::Middleware::SocketIO::Handle;

sub name {'websocket'}

sub finalize {
    my $self = shift;
    my ($cb) = @_;

    my $fh = $self->req->env->{'psgix.io'};
    return unless $fh;

    my $hs = Protocol::WebSocket::Handshake::Server->new_from_psgi($self->req->env);
    return unless $hs->parse($fh);

    return unless $hs->is_done;

    my $handle = $self->_build_handle($fh);
    my $frame = Protocol::WebSocket::Frame->new;

    return sub {
        my $respond = shift;

        $handle->write(
            $hs->to_string => sub {
                my $handle = shift;

                my $conn = $self->add_connection(on_connect => $cb);

                $handle->heartbeat_timeout(10);
                $handle->on_heartbeat(sub { $conn->send_heartbeat });

                $handle->on_read(
                    sub {
                        my $handle = shift;

                        $frame->append($_[0]);

                        while (my $message = $frame->next) {
                            $conn->read($message);
                        }
                    }
                );

                $handle->on_eof(
                    sub {
                        $handle->close;

                        $self->client_disconnected($conn);
                    }
                );

                $handle->on_error(
                    sub {
                        $self->client_disconnected($conn);

                        $handle->close;
                    }
                );

                $conn->on_write(
                    sub {
                        my $conn = shift;
                        my ($message) = @_;

                        $message = $self->_build_frame($message);

                        $handle->write($message);
                    }
                );

                $conn->send_id_message($conn->id);

                $self->client_connected($conn);
            }
        );
    };
}

sub _build_frame {
    my $self = shift;
    my ($message) = @_;

    return Protocol::WebSocket::Frame->new($message)->to_string;
}

1;
__END__

=head1 NAME

Plack::Middleware::SocketIO::WebSocket - WebSocket transport

=head1 DESCRIPTION

L<Plack::Middleware::SocketIO::WebSocket> is a WebSocket transport implementation.

=head1 SEE ALSO

L<Protocol::WebSocket>

=cut
