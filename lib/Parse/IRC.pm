package Parse::IRC;

# We export some stuff
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(parse_irc);

use strict;
use warnings;
use vars qw($VERSION);

$VERSION = '1.12';

my $g = {
  space			=> qr/\x20+/o,
  trailing_space	=> qr/\x20*/o,
};

my $irc_regex = qr/^
  (?:
    \x3a                #  : comes before hand
    (\S+)               #  [prefix]
    $g->{'space'}       #  Followed by a space
  )?                    # but is optional.
  (
    \d{3}|[a-zA-Z]+     #  [command]
  )                     # required.
  (?:
    $g->{'space'}       # Strip leading space off [middle]s
    (                   # [middle]s
      (?:
        [^\x00\x0a\x0d\x20\x3a]
        [^\x00\x0a\x0d\x20]*
      )                 # Match on 1 of these,
      (?:
        $g->{'space'}
        [^\x00\x0a\x0d\x20\x3a]
        [^\x00\x0a\x0d\x20]*
      ){0,13}           # then match on 0-13 of these,
    )
  )?                    # otherwise dont match at all.
  (?:
    $g->{'space'}\x3a   # Strip off leading spacecolon for [trailing]
    ([^\x00\x0a\x0d]*)	# [trailing]
  )?                    # [trailing] is not necessary.
  $g->{'trailing_space'}
$/x;

sub parse_irc {
  my $string = shift || return;
  return __PACKAGE__->new(@_)->parse($string);
}

sub new {
  my $package = shift;
  my %opts = @_;
  $opts{lc $_} = delete $opts{$_} for keys %opts;
  return bless \%opts, $package;
}

sub parse {
  my $self = shift;
  my $raw_line = shift || return;
  $raw_line =~ s/(\x0D\x0A?|\x0A\x0D?)$//;
  if ( my($prefix, $command, $middles, $trailing) = $raw_line =~ m/$irc_regex/ ) {
      my $event = { raw_line => $raw_line };
      $event->{'prefix'} = $prefix if $prefix;
      $event->{'command'} = uc $command;
      $event->{'params'} = [] if ( defined ( $middles ) || defined ( $trailing ) );
      push @{$event->{'params'}}, (split /$g->{'space'}/, $middles) if defined ( $middles );
      push @{$event->{'params'}}, $trailing if defined( $trailing );
      if ( $self->{public} and $event->{'command'} eq 'PRIVMSG' and $event->{'params'}->[0] =~ /^(\x23|\x26)/ ) {
	$event->{'command'} = 'PUBLIC';
      }
      return $event;
  } 
  else {
      warn "Received line $raw_line that is not IRC protocol\n" if $self->{debug};
  }
  return;
}

1;

__END__

=head1 NAME

Parse::IRC - A parser for the IRC protocol.

=head1 SYNOPSIS

General usage:

  use strict;
  use Parse::IRC;

  # Functional interface

  my $hashref = parse_irc( $irc_string );

  # OO interface

  my $irc_parser = Parse::IRC->new();

  my $hashref = $irc_parser->parse( $irc_string );

Using Parse::IRC in a simple IRC bot:

  # A simple IRC bot using Parse::IRC

  use strict;
  use IO::Socket;
  use Parse::IRC;

  my $parser = Parse::IRC->new( public => 1 );

  my %dispatch = ( 'ping' => \&irc_ping, '001' => \&irc_001, 'public' => \&irc_public );

  # The server to connect to and our details.
  my $server = "irc.perl.moo";
  my $nick = "parseirc$$";
  my $login = "simple_bot";

  # The channel which the bot will join.
  my $channel = "#IRC.pm";

  # Connect to the IRC server.
  my $sock = new IO::Socket::INET(PeerAddr => $server,
                                  PeerPort => 6667,
                                  Proto => 'tcp') or
                                    die "Can't connect\n";

  # Log on to the server.
  print $sock "NICK $nick\r\n";
  print $sock "USER $login 8 * :Perl IRC Hacks Robot\r\n";

  # Keep reading lines from the server.
  while (my $input = <$sock>) {
    $input =~ s/\r\n//g;
    my $hashref = $parser->parse( $input );
    SWITCH: {
          my $type = lc $hashref->{command};
          my @args;
          push @args, $hashref->{prefix} if $hashref->{prefix};
          push @args, @{ $hashref->{params} };
          if ( defined $dispatch{$type} ) {
            $dispatch{$type}->(@args);
            last SWITCH;
          }
          print STDOUT join( ' ', "irc_$type:", @args ), "\n";
    }
  }

  sub irc_ping {
    my $server = shift;
    print $sock "PONG :$server\r\n";
    return 1;
  }

  sub irc_001 {
    print STDOUT "Connected to $_[0]\n";
    print $sock "JOIN $channel\r\n";
    return 1;
  }

  sub irc_public {
    my ($who,$where,$what) = @_;
    print "$who -> $where -> $what\n";
    return 1;
  }

=head1 DESCRIPTION

Parse::IRC provides a convenient way of parsing lines of text conforming to the IRC 
protocol ( see RFC1459 or RFC2812 ).

=head1 FUNCTION INTERFACE

Using the module automagically imports 'parse_irc' into your namespace.

=over

=item parse_irc

Takes a string of IRC protcol text. Returns a hashref on success or undef on failure.
See below for the format of the hashref returned.

=back

=head1 OBJECT INTERFACE

=head2 CONSTRUCTOR

=over 

=item new

Creates a new Parse::IRC object. One may specify debug => 1 to enable warnings about non-IRC
protcol lines. Specify public => 1 to enable the automatic conversation of privmsgs targeted at
channels to 'public' instead of 'privmsg'.

=back

=head2 METHODS

=over 

=item parse

Takes a string of IRC protcol text. Returns a hashref on success or undef on failure.
The hashref contains the following fields:

  prefix
  command
  params ( this is an arrayref )
  raw_line 

For example, if the filter receives the following line, the following hashref is produced:

  LINE: ':moo.server.net 001 lamebot :Welcome to the IRC network lamebot'

  HASHREF: {
	     prefix   => ':moo.server.net',
	     command  => '001',
	     params   => [ 'lamebot', 'Welcome to the IRC network lamebot' ],
	     raw_line => ':moo.server.net 001 lamebot :Welcome to the IRC network lamebot',
	   }


=back

=head1 AUTHOR

Chris 'BinGOs' Williams

Based on code originally developed by Jonathan Steinert

=head1 LICENSE

Copyright C<(c)> Chris Williams and Jonathan Steinert

This module may be used, modified, and distributed under the same terms as Perl itself. Please see the license that came with your Perl distribution for details.

=head1 SEE ALSO

L<POE::Filter::IRCD>

L<http://www.faqs.org/rfcs/rfc1459.html>

L<http://www.faqs.org/rfcs/rfc2812.html>

