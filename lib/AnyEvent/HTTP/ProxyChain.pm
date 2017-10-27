=head1 NAME

AnyEvent::HTTP::ProxyChain - AnyEvent::HTTP with proxy chaining support

=head1 SYNOPSIS

    use AnyEvent::HTTP::ProxyChain;

    http_get "https://my.mail.ru/",
        proxy => [ ["proxy1.example.com", 3128], ["proxy2.example.com", 3128] ],
        sub { print $_[1] };

    # ... do something else here

=head1 DESCRIPTION

This module is a simple wrapper around L<AnyEvent::HTTP>. It provides the same
functionality with one simple addition: it supports chains of multiple
proxy servers.

=cut

package AnyEvent::HTTP::ProxyChain;

use strict;
use warnings;
use AnyEvent::HTTP 2 ();
use AnyEvent::Socket;

use Exporter 'import';

our $VERSION = '1.01';

our @EXPORT = qw/http_get http_post http_head http_request/;

sub http_request($$@) {
    my $cb = pop;
    my ($method, $url, %args) = @_;
    if (exists $args{proxy}) {
        my $proxy = delete $args{proxy};
        my @proxies = @$proxy && ref $proxy->[0] eq 'ARRAY' ? @$proxy : $proxy;
        $args{proxy} = pop @proxies;
        if (@proxies) {
            my $tcp_connect = delete $args{tcp_connect} || \&AnyEvent::Socket::tcp_connect;
            my $timeout = $args{timeout} || $AnyEvent::HTTP::TIMEOUT;
            $args{tcp_connect} = sub {
                my ($host, $port, $on_connect, $on_prepare) = @_;
                push @proxies, [$host, $port];
                my ($first_host, $first_port) = @{shift @proxies};
                my $proxy_connect = sub {
                    my ($fh) = @_;
                    my $next;

                    my $handle = AnyEvent::Handle->new(
                        %{$args{handle_params}},
                        fh       => $fh,
                        peername => $host,
                        tls_ctx  => $args{tls_ctx},
                        on_error => sub { undef $next; $cb->(undef, { URL => $url, Status => 595, Reason => $_[2] }) },
                        on_eof   => sub { undef $next; $cb->(undef, { URL => $url, Status => 595, Reason => "Unexpected end-of-file" }) },
                        timeout  => $timeout,
                    );

                    $next = sub {
                        if (my $proxy = shift @proxies) {
                            my ($host, $port) = @$proxy;
                            $handle->push_write("CONNECT $host:$port HTTP/1.0\015\012\015\012");
                            $handle->push_read(line => $AnyEvent::HTTP::qr_nlnl, sub {
                                if ($_[1] =~ /^HTTP\/([0-9\.]+) \s+ ([0-9]{3}) (?: \s+ ([^\015\012]*) )?/ix) {
                                    if ($2 == 200) {
                                        $next->();
                                    } else {
                                        undef $next;
                                        $cb->(undef, { URL => $url, Status => $2, Reason => $3 });
                                    }
                                } else {
                                    undef $next;
                                    $cb->(undef, { URL => $url, Status => 599, Reason => "Invalid proxy connect response ($_[1])" });
                                }
                            });
                        } else {
                            undef $next;
                            $on_connect->($fh);
                        }
                    };
                    $next->();
                };
                return $tcp_connect->($first_host, $first_port, $proxy_connect, $on_prepare);
            };
        }
    }
    return AnyEvent::HTTP::http_request($method, $url, %args, $cb);
}

sub http_get($@) {
    unshift @_, "GET";
    &http_request;
}

sub http_head($@) {
    unshift @_, "HEAD";
    &http_request;
}

sub http_post($$@) {
    my $url = shift;
    unshift @_, "POST", $url, "body";
    &http_request;
}

=head1 SEE ALSO

L<AnyEvent::HTTP>.

=head1 AUTHOR

Aleksey Mashanov <a.mashanov@corp.mail.ru>

=head1 LICENSE

Copyright (c) 2017 Mail.Ru Group.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
