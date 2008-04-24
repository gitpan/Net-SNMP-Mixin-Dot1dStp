package Net::SNMP::Mixin::Dot1dStp;

use strict;
use warnings;

#
# store this package name in a handy variable,
# used for unambiguous prefix of mixin attributes
# storage in object hash
#
my $prefix = __PACKAGE__;

#
# this module import config
#
use Carp ();
use Net::SNMP::Mixin::Util qw/idx2val hex2octet normalize_mac/;

#
# this module export config
#
my @mixin_methods;

BEGIN {
  @mixin_methods = (
    qw/
      get_dot1d_stp_group
      get_dot1d_stp_port_table
      /
  );
}

use Sub::Exporter -setup => {
  exports => [@mixin_methods],
  groups  => { default => [@mixin_methods], },
};

#
# SNMP oid constants used in this module
#
use constant {
  DOT1D_STP_GROUP => '1.3.6.1.2.1.17.2',

  DOT1D_STP_PROTO                  => '1.3.6.1.2.1.17.2.1.0',
  DOT1D_STP_PRIO                   => '1.3.6.1.2.1.17.2.2.0',
  DOT1D_STP_TIME_SINCE_TOPO_CHANGE => '1.3.6.1.2.1.17.2.3.0',
  DOT1D_STP_TOPO_CHANGES           => '1.3.6.1.2.1.17.2.4.0',
  DOT1D_STP_DESIGNATED_ROOT        => '1.3.6.1.2.1.17.2.5.0',
  DOT1D_STP_ROOT_COST              => '1.3.6.1.2.1.17.2.6.0',
  DOT1D_STP_ROOT_PORT              => '1.3.6.1.2.1.17.2.7.0',
  DOT1D_STP_MAX_AGE                => '1.3.6.1.2.1.17.2.8.0',
  DOT1D_STP_HELLO_TIME             => '1.3.6.1.2.1.17.2.9.0',
  DOT1D_STP_HOLD_TIME              => '1.3.6.1.2.1.17.2.10.0',
  DOT1D_STP_FWD_DELAY              => '1.3.6.1.2.1.17.2.11.0',
  DOT1D_STP_BRIDGE_MAX_AGE         => '1.3.6.1.2.1.17.2.12.0',
  DOT1D_STP_BRIDGE_HELLO_TIME      => '1.3.6.1.2.1.17.2.13.0',
  DOT1D_STP_BRIDGE_FWD_DELAY       => '1.3.6.1.2.1.17.2.14.0',

  DOT1D_STP_PORT_TABLE => '1.3.6.1.2.1.17.2.15',

  DOT1D_STP_PORT_INDEX               => '1.3.6.1.2.1.17.2.15.1.1',
  DOT1D_STP_PORT_PRIO                => '1.3.6.1.2.1.17.2.15.1.2',
  DOT1D_STP_PORT_STATE               => '1.3.6.1.2.1.17.2.15.1.3',
  DOT1D_STP_PORT_ENABLE              => '1.3.6.1.2.1.17.2.15.1.4',
  DOT1D_STP_PORT_PATH_COST           => '1.3.6.1.2.1.17.2.15.1.5',
  DOT1D_STP_PORT_DESIGNATED_ROOT     => '1.3.6.1.2.1.17.2.15.1.6',
  DOT1D_STP_PORT_DESIGNATED_COST     => '1.3.6.1.2.1.17.2.15.1.7',
  DOT1D_STP_PORT_DESIGNATED_BRIDGE   => '1.3.6.1.2.1.17.2.15.1.8',
  DOT1D_STP_PORT_DESIGNATED_PORT     => '1.3.6.1.2.1.17.2.15.1.9',
  DOT1D_STP_PORT_FORWARD_TRANSITIONS => '1.3.6.1.2.1.17.2.15.1.10',
};

#
# The port's current state translation table
#
my %port_state_enum = (
  1 => 'disabled',
  2 => 'blocking',
  3 => 'listening',
  4 => 'learning',
  5 => 'forwarding',
  6 => 'broken',
);

=head1 NAME

Net::SNMP::Mixin::Dot1dStp - mixin class for 802.1D spanning tree information

=head1 VERSION

Version 0.01_01

=cut

our $VERSION = '0.01_01';

=head1 SYNOPSIS

A mixin class for Net::SNMP for spanning tree info.

  use Net::SNMP;
  use Net::SNMP::Mixin qw/mixer init_mixins/;

  my $session = Net::SNMP->session( -hostname => 'foo.bar.com' );

  # object based mixin
  $session->mixer('Net::SNMP::Mixin::Dot1dStp');

  $session->init_mixins;
  snmp_dispatcher() if $session->nonblocking;
  die $session->error if $session->error;

  TODO

=head1 DESCRIPTION

TODO

=head1 MIXIN METHODS

=cut

=head2 B<< OBJ->get_dot1d_stp_group() >>

Returns the dot1dStp group as a hash reference:

  {
    dot1dStpProtocolSpecification   => INTEGER,
    dot1dStpPriority                => INTEGER,
    dot1dStpTimeSinceTopologyChange => TIME_TICKS,
    dot1dStpTopChanges              => COUNTER,
    dot1dStpRootCost                => INTEGER,
    dot1dStpRootPort                => INTEGER,
    dot1dStpMaxAge                  => TIMEOUT,
    dot1dStpHelloTime               => TIMEOUT,
    dot1dStpHoldTime                => INTEGER,
    dot1dStpForwardDelay            => TIMEOUT,
    dot1dStpBridgeMaxAge            => TIMEOUT,
    dot1dStpBridgeHelloTime         => TIMEOUT,
    dot1dStpBridgeForwardDelay      => TIMEOUT,
    dot1dStpDesignatedRoot          => BridgeId,
    dot1dStpDesignatedRootPriority => INTEGER,
    dot1dStpDesignatedRootAddress  => MacAddress,
  }


The dot1dStpDesignatedRoot is a BridgeId struct of priority and MacAddress. The mixin method splits this already into dot1dStpDesignatedRootPriority and dot1dStpDesignatedRootAddress for your convenience.

=cut

sub get_dot1d_stp_group {
  my $session = shift;
  Carp::croak "'$prefix' not initialized,"
    unless $session->{$prefix}{__initialized};

  my $result = {};

  $result->{dot1dStpProtocolSpecification} =
    $session->{$prefix}{dot1dStpProtocolSpecification};
  $result->{dot1dStpPriority} = $session->{$prefix}{dot1dStpPriority};
  $result->{dot1dStpTimeSinceTopologyChange} =
    $session->{$prefix}{dot1dStpTimeSinceTopologyChange};
  $result->{dot1dStpTopChanges}     = $session->{$prefix}{dot1dStpTopChanges};
  $result->{dot1dStpDesignatedRoot} =
    $session->{$prefix}{dot1dStpDesignatedRoot};
  $result->{dot1dStpRootCost}     = $session->{$prefix}{dot1dStpRootCost};
  $result->{dot1dStpRootPort}     = $session->{$prefix}{dot1dStpRootPort};
  $result->{dot1dStpMaxAge}       = $session->{$prefix}{dot1dStpMaxAge};
  $result->{dot1dStpHelloTime}    = $session->{$prefix}{dot1dStpHelloTime};
  $result->{dot1dStpHoldTime}     = $session->{$prefix}{dot1dStpHoldTime};
  $result->{dot1dStpForwardDelay} = $session->{$prefix}{dot1dStpForwardDelay};
  $result->{dot1dStpBridgeMaxAge} = $session->{$prefix}{dot1dStpBridgeMaxAge};
  $result->{dot1dStpBridgeHelloTime} =
    $session->{$prefix}{dot1dStpBridgeHelloTime};
  $result->{dot1dStpBridgeForwardDelay} =
    $session->{$prefix}{dot1dStpBridgeForwardDelay};

  ######
  # calculated values from the structs
  ######

  # split BridgeId in priority and address
  my ( $root_bridge_prio, $root_bridge_address ) =
    _unpack_bridge_id( $result->{dot1dStpDesignatedRoot} );

  $result->{dot1dStpDesignatedRootPriority} = $root_bridge_prio;
  $result->{dot1dStpDesignatedRootAddress}  = $root_bridge_address;

  return $result;
}

=head2 B<< OBJ->get_dot1d_stp_port_table() >>

Returns the dot1dStpPortTable as a hash reference. The keys are the dot1d STP port numbers for which this entry contains Spanning Tree Protocol management information:

  {
    INTEGER => { # dot1dStpPort 

      dot1dStpPortPriority           => INTEGER,
      dot1dStpPortState              => INTEGER,
      dot1dStpPortStateString        => String,
      dot1dStpPortEnable             => INTEGER,
      dot1dStpPortPathCost           => INTEGER,
      dot1dStpPortDesignatedRootId   => BridgeId,
      dot1dStpPortDesignatedCost     => INTEGER,
      dot1dStpPortDesignatedBridgeId => BridgeId,
      dot1dStpPortDesignatedPort     => PortId,
      dot1dStpPortForwardTransitions => COUNTER,

      # dot1dStpPortDesignatedRootId is a struct (BridgeId) of
      # priority and MacAddress
      #
      dot1dStpPortDesignatedRootPriority => INTEGER,
      dot1dStpPortDesignatedRootAddress  => MacAddress,

      # dot1dStpPortDesignatedBridgeId is a struct (BridgeId) of
      # priority and MacAddress
      #
      dot1dStpPortDesignatedBridgePriority => INTEGER,
      dot1dStpPortDesignatedBridgeAddress  => MacAddress,

      # dot1dStpPortDesignatedPort is a struct (PortId) of
      # priority and bridge port number
      #
      dot1dStpPortDesignatedPortPriority => INTEGER,
      dot1dStpPortDesignatedPortNumber   => INTEGER,

      }
  }

The structs BridgeId and PortId are already splitted by this mixin method into the relevant values for your convenience.

The dot1dStpPort has the same value as the dot1dBasePort and isn't necessarily the ifIndex of the switch.

See also the L<< Net::SNMP::Mixin::Dot1dBase >> for a mixin to get the mapping between the ifIndexes and the dot1dBasePorts if needed.

=cut

sub get_dot1d_stp_port_table {
  my $session = shift;
  Carp::croak "'$prefix' not initialized,"
    unless $session->{$prefix}{__initialized};

  # stash for return values
  my $dot1dStpPortTable = {};

  # dot1dStpPortTable index
  my @tableIndexes = keys %{ $session->{$prefix}{dot1dStpPortPriority} };

  foreach my $idx (@tableIndexes) {
    my $row = {};
    my (
      $port_state,     $port_state_string, $bridge_prio,
      $bridge_address, $portPrio,          $portNumber
    );

    $row->{dot1dStpPortPriority} =
      $session->{$prefix}{dot1dStpPortPriority}{$idx};

    $row->{dot1dStpPortState} = $session->{$prefix}{dot1dStpPortState}{$idx};

    $row->{dot1dStpPortEnable} = $session->{$prefix}{dot1dStpPortEnable}{$idx};

    $row->{dot1dStpPortPathCost} =
      $session->{$prefix}{dot1dStpPortPathCost}{$idx};

    $row->{dot1dStpPortDesignatedRoot} =
      $session->{$prefix}{dot1dStpPortDesignatedRoot}{$idx};

    $row->{dot1dStpPortDesignatedCost} =
      $session->{$prefix}{dot1dStpPortDesignatedCost}{$idx};

    $row->{dot1dStpPortDesignatedBridge} =
      $session->{$prefix}{dot1dStpPortDesignatedBridge}{$idx};

    $row->{dot1dStpPortDesignatedPort} =
      $session->{$prefix}{dot1dStpPortDesignatedPort}{$idx};

    $row->{dot1dStpPortForwardTransitions} =
      $session->{$prefix}{dot1dStpPortForwardTransitions}{$idx};

    ######
    # calculated values from the structs
    ######

    $port_state                     = $row->{dot1dStpPortState};
    $port_state_string              = $port_state_enum{$port_state};
    $row->{dot1dStpPortStateString} = $port_state_string;

    ( $bridge_prio, $bridge_address ) =
      _unpack_bridge_id( $row->{dot1dStpPortDesignatedRoot} );
    $row->{dot1dStpPortDesignatedRootPriority} = $bridge_prio;
    $row->{dot1dStpPortDesignatedRootAddress}  = $bridge_address;

    ( $bridge_prio, $bridge_address ) =
      _unpack_bridge_id( $row->{dot1dStpPortDesignatedBridge} );
    $row->{dot1dStpPortDesignatedBridgePriority} = $bridge_prio;
    $row->{dot1dStpPortDesignatedBridgeAddress}  = $bridge_address;

    ( $portPrio, $portNumber ) =
      _unpack_bridge_port_id( $row->{dot1dStpPortDesignatedPort} );
    $row->{dot1dStpPortDesignatedPortPriority} = $portPrio;
    $row->{dot1dStpPortDesignatedPortNumber}   = $portNumber;

    $dot1dStpPortTable->{$idx} = $row;
  }

  return $dot1dStpPortTable;
}

=head1 INITIALIZATION

=head2 B<< OBJ->_init($reload) >>

Fetch the dot1dSTP related snmp values from the host. Don't call this method direct!

=cut

sub _init {
  my ( $session, $reload ) = @_;

  die "$prefix already initalized and reload not forced.\n"
    if $session->{$prefix}{__initialized} && not $reload;

  # populate the object with needed mib values
  #
  # initialize the object for STP infos
  _fetch_dot1d_stp_group($session);
  return if $session->error;

  _fetch_dot1d_stp_port_tbl($session);
  return if $session->error;

  return 1;
}

=head1 PRIVATE SUBROUTINES

=head2 B<< _fetch_dot1d_stp_group($session) >>

Fetch the local system data from the dot1dStp tree once during object initialization.

=cut

sub _fetch_dot1d_stp_group {
  my $session = shift;
  my $result;

  $result = $session->get_request(
    -varbindlist => [

      DOT1D_STP_PROTO,
      DOT1D_STP_PRIO,
      DOT1D_STP_TIME_SINCE_TOPO_CHANGE,
      DOT1D_STP_TOPO_CHANGES,
      DOT1D_STP_DESIGNATED_ROOT,
      DOT1D_STP_ROOT_COST,
      DOT1D_STP_ROOT_PORT,
      DOT1D_STP_MAX_AGE,
      DOT1D_STP_HELLO_TIME,
      DOT1D_STP_HOLD_TIME,
      DOT1D_STP_FWD_DELAY,
      DOT1D_STP_BRIDGE_MAX_AGE,
      DOT1D_STP_BRIDGE_HELLO_TIME,
      DOT1D_STP_BRIDGE_FWD_DELAY,
    ],

    # define callback if in nonblocking mode
    $session->nonblocking
    ? ( -callback => \&_dot1d_stp_group_cb )
    : (),

  );

  return unless defined $result;
  return 1 if $session->nonblocking;

  # call the callback function in blocking mode by hand
  # in order to process the result
  _dot1d_stp_group_cb($session);

}

=head2 B<< _dot1d_stp_group_cb($session) >>

The callback for _fetch_dot1d_stp_group.

=cut

sub _dot1d_stp_group_cb {
  my $session = shift;
  my $vbl     = $session->var_bind_list;

  return unless defined $vbl;

  $session->{$prefix}{dot1dStpProtocolSpecification} =
    $vbl->{ DOT1D_STP_PROTO() };

  $session->{$prefix}{dot1dStpPriority} = $vbl->{ DOT1D_STP_PRIO() };

  $session->{$prefix}{dot1dStpTimeSinceTopologyChange} =
    $vbl->{ DOT1D_STP_TIME_SINCE_TOPO_CHANGE() };

  $session->{$prefix}{dot1dStpTopChanges} = $vbl->{ DOT1D_STP_TOPO_CHANGES() };

  $session->{$prefix}{dot1dStpDesignatedRoot} =
    $vbl->{ DOT1D_STP_DESIGNATED_ROOT() };

  $session->{$prefix}{dot1dStpRootCost} = $vbl->{ DOT1D_STP_ROOT_COST() };

  $session->{$prefix}{dot1dStpRootPort} = $vbl->{ DOT1D_STP_ROOT_PORT() };

  $session->{$prefix}{dot1dStpMaxAge} = $vbl->{ DOT1D_STP_MAX_AGE() };

  $session->{$prefix}{dot1dStpHelloTime} = $vbl->{ DOT1D_STP_HELLO_TIME() };

  $session->{$prefix}{dot1dStpHoldTime} = $vbl->{ DOT1D_STP_HOLD_TIME() };

  $session->{$prefix}{dot1dStpForwardDelay} = $vbl->{ DOT1D_STP_FWD_DELAY() };

  $session->{$prefix}{dot1dStpBridgeMaxAge} =
    $vbl->{ DOT1D_STP_BRIDGE_MAX_AGE() };

  $session->{$prefix}{dot1dStpBridgeHelloTime} =
    $vbl->{ DOT1D_STP_BRIDGE_HELLO_TIME() };

  $session->{$prefix}{dot1dStpBridgeForwardDelay} =
    $vbl->{ DOT1D_STP_BRIDGE_FWD_DELAY() };

  $session->{$prefix}{__initialized}++;
}

=head2 B<< _fetch_dot1d_stp_port_tbl($session) >>

Fetch the dot1dStpPortTable once during object initialization.

=cut

sub _fetch_dot1d_stp_port_tbl {
  my $session = shift;
  my $result;

  # fetch the dot1dStpPortTable
  $result = $session->get_table(
    -baseoid => DOT1D_STP_PORT_TABLE,

    # define callback if in nonblocking mode
    $session->nonblocking
    ? ( -callback => \&_dot1d_stp_port_tbl_cb )
    : (),
  );

  return unless defined $result;
  return 1 if $session->nonblocking;

  # call the callback function in blocking mode by hand
  # in order to process the result
  _dot1d_stp_port_tbl_cb($session);

}

=head2 B<< _dot1d_stp_port_tbl_cb($session) >>

The callback for _fetch_dot1d_stp_port_tbl().

=cut

sub _dot1d_stp_port_tbl_cb {
  my $session = shift;
  my $vbl     = $session->var_bind_list;

  return unless defined $vbl;

  $session->{$prefix}{dot1dStpPortPriority} =
    idx2val( $vbl, DOT1D_STP_PORT_PRIO );

  $session->{$prefix}{dot1dStpPortState} =
    idx2val( $vbl, DOT1D_STP_PORT_STATE );

  $session->{$prefix}{dot1dStpPortEnable} =
    idx2val( $vbl, DOT1D_STP_PORT_ENABLE );

  $session->{$prefix}{dot1dStpPortPathCost} =
    idx2val( $vbl, DOT1D_STP_PORT_PATH_COST );

  $session->{$prefix}{dot1dStpPortDesignatedRoot} =
    idx2val( $vbl, DOT1D_STP_PORT_DESIGNATED_ROOT );

  $session->{$prefix}{dot1dStpPortDesignatedCost} =
    idx2val( $vbl, DOT1D_STP_PORT_DESIGNATED_COST );

  $session->{$prefix}{dot1dStpPortDesignatedBridge} =
    idx2val( $vbl, DOT1D_STP_PORT_DESIGNATED_BRIDGE );

  $session->{$prefix}{dot1dStpPortDesignatedPort} =
    idx2val( $vbl, DOT1D_STP_PORT_DESIGNATED_PORT );

  $session->{$prefix}{dot1dStpPortForwardTransitions} =
    idx2val( $vbl, DOT1D_STP_PORT_FORWARD_TRANSITIONS );

  $session->{$prefix}{__initialized}++;
}

=head2 B<< _unpack_bridge_id($bridgeId) >>

Split a bridge id in priority and MAC address. Returns a list of (bridgePrio, bridgeMac).

=cut

sub _unpack_bridge_id {
  my $bridgeId = shift;
  return unless $bridgeId;

  # convert to untranslated OCTET_STRING in case it's
  # already translated by Net::SNMP
  $bridgeId = hex2octet($bridgeId);

  # the bridgeId struct is the concatenation of:
  #   dot1dStpPriority and dot1dStpBridgeMAC
  #
  # unpack the struct
  my ( $bridgePrio, $bridgeMac ) = unpack 'nH*', $bridgeId;

  # convert to a normalized adress format
  $bridgeMac = normalize_mac($bridgeMac);

  return ( $bridgePrio, $bridgeMac );
}

=head2 B<< _unpack_bridge_port_id($bridgePortId) >>

Split a bridge port id in priority and bridge port number. Returns a list of (portPrio, portNumber).

=cut

sub _unpack_bridge_port_id {
  my $portId = shift;
  return unless $portId;

  # convert to untranslated OCTET_STRING in case it's
  # already translated by Net::SNMP
  $portId = hex2octet($portId);

  # the portId is the concatenation of:
  #   portPriority(4bit) and dot1dBasePort(12bit)
  #
  my $portPrio      = ( unpack 'n', $portId ) >> 12;
  my $dot1dBasePort = ( unpack 'n', $portId ) & 0x0FFF;

  # priority <0-15> (default: 8 ) - The range of 0-240 is
  # divided into 16 steps. These steps are numbered from
  # 0 to 15. It is multiplied by 16 to calculate the
  # priority value used by the STP protocol.

  $portPrio *= 16;

  return ( $portPrio, $dot1dBasePort );
}

=head1 SEE ALSO

L<< Net::SNMP::Mixin::Dot1dBase >>

=head1 REQUIREMENTS

L<< Net::SNMP >>, L<< Net::SNMP::Mixin >>

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a bug or are experiencing difficulties that are not explained within the POD documentation, please submit a bug to the RT system (see link below). However, it would help greatly if you are able to pinpoint problems or even supply a patch. 

Fixes are dependant upon their severity and my availablity. Should a fix not be forthcoming, please feel free to (politely) remind me by sending an email to gaissmai@cpan.org .

  RT: http://rt.cpan.org/Public/Dist/Display.html?Name=Net-SNMP-Mixin-Dot1dStp

=head1 AUTHOR

Karl Gaissmaier <karl.gaissmaier at uni-ulm.de>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Karl Gaissmaier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

unless ( caller() ) {
  print "$prefix compiles and initializes successful.\n";
}

1;

# vim: sw=2
