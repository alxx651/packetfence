package pf::UnifiedApi::Controller::Nodes;

=head1 NAME

pf::UnifiedApi::Controller::Nodes -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Nodes

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use NetAddr::IP;
use pf::dal::node;
use pf::fingerbank;
use pf::parking;
use pf::node;
use List::Util qw(first);
use List::MoreUtils qw(part);
use pf::ip4log;
use pf::constants qw($TRUE $default_pid);
use pf::dal::security_event;
use pf::error qw(is_error is_success);
use pf::locationlog qw(locationlog_history_mac locationlog_view_open_mac);
use pf::UnifiedApi::Search::Builder::Nodes;
use pf::UnifiedApi::Search::Builder::NodesNetworkGraph;
use pf::security_event;
use pf::Connection;
use pf::SwitchFactory;
use pf::util qw(valid_ip valid_mac);
use pf::Connection::ProfileFactory;
use pf::log;

has 'search_builder_class' => 'pf::UnifiedApi::Search::Builder::Nodes';

has dal => 'pf::dal::node';
has url_param_name => 'node_id';
has primary_key => 'mac';

=head2 register

register

=cut

sub register {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }
    my $node = $self->item;
    my $mac = $node->{mac};

    my $pid = delete $data->{pid};
    if (!defined $pid || length($pid) == 0) {
        $pid = $node->{pid}
    }

    my ($success, $msg) = node_register($mac, $pid, %$data);
    if (!$success) {
        return $self->render_error(422, "Cannot register $mac" . ($msg ? " $msg" : ""));
    }

    return $self->render(json => {}, status => 200);
}

=head2 deregister

deregister

=cut

sub deregister {
    my ($self) = @_;
    my $mac = $self->id;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my ($success) = node_deregister($mac, %$data);
    if (!$success) {
        return $self->render_error(422, "Cannot deregister $mac");
    }

    return $self->render(json => {}, status => 200);
}

=head2 bulk_register

bulk_register

=cut

sub bulk_register {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    ($status, my $iter) = $self->dal->search(
        -columns => [qw(mac pid node.category_id)],
        -where => {
            mac => { -in => $items},
            status => { "!=" => $pf::node::STATUS_REGISTERED }
        },
        -with_class => undef,
    );
    if (is_error($status)) {
        return $self->render_error($status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items);
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $mac = $node->{mac};
        my ($result, $msg) = node_register($mac, $node->{pid}, category_id => delete $node->{category_id});
        my $index = $indexes->{$mac};
        if ($result) {
            $results->[$index]{status} = "success";
            pf::enforcement::reevaluate_access($mac, "admin_modify");
        } else {
            $results->[$index]{status} = "failed";
            $results->[$index]{message} = $msg // '';
        }
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 bulk_init_results

bulk_init_results

=cut

sub bulk_init_results {
    my ($items) = @_;
    my $i = 0;
    my %index = map { $_ => $i++ } @$items;
    my @results = map { { mac => $_, status => 'skipped'} } @$items;
    return (\%index, \@results);
}

=head2 bulk_deregister

bulk_deregister

=cut

sub bulk_deregister {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    ($status, my $iter) = $self->dal->search(
        -columns => [qw(mac pid)],
        -where => {
            mac => { -in => $items},
            status => { "!=" => $pf::node::STATUS_UNREGISTERED }
        },
        -with_class => undef,
    );
    if (is_error($status)) {
        return $self->render_error($status, "Error finding nodes");
    }

    my ($index, $results) = bulk_init_results($items);
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $mac = $node->{mac};
        my $result = node_deregister($mac);
        if ($result) {
            pf::enforcement::reevaluate_access($mac, "admin_modify");
        }
        $results->[$index->{$mac}]{status} = $result ? "success" : "failed";
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 fingerbank_info

fingerbank_info

=cut

sub fingerbank_info {
    my ($self) = @_;
    my $mac = $self->id;
    return $self->render(status => 200, json => { item => pf::node::fingerbank_info($mac) });
}

=head2 fingerbank_refresh

fingerbank_refresh

=cut

sub fingerbank_refresh {
    my ($self) = @_;
    my $mac = $self->id;
    unless (pf::fingerbank::process($mac, $TRUE)) {
        return $self->render_error(500, "Couldn't refresh device profiling through Fingerbank");
    }

    return $self->render(json => {}, status => 200);
}

=head2 bulk_close_security_events

bulk_close_security_events

=cut

sub bulk_close_security_events {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    ($status, my $iter) = pf::dal::security_event->search(
        -where => {
            mac => { -in => $items},
            status => "open",
        },
        -columns => [qw(security_event.security_event_id mac)],
        -from => [-join => qw(security_event <=>{security_event.security_event_id=class.security_event_id} class)],
        -order_by => { -desc => 'start_date' },
        -with_class => undef,
    );

    if (is_error($status)) {
        return $self->render_error($status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items);
    my $security_events = $iter->all;
    for my $security_event (@$security_events) {
        my $mac = $security_event->{mac};
        my $index = $indexes->{$mac};
        if (security_event_force_close($mac, $security_event->{security_event_id})) {
            pf::enforcement::reevaluate_access($mac, "admin_modify");
            $results->[$index]{status} = "success";
        } else {
            $results->[$index]{status} = "failed";
        }
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 close_security_event

close_security_event

=cut

sub close_security_event {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }
    my $mac = $self->id;
    my $security_event_id = $data->{security_event_id};
    my $security_event = security_event_exist_id($security_event_id);
    if (!$security_event || $security_event->{mac} ne $mac ) {
        return $self->render_error(404, "Error finding security event");
    }

    my $result = 0;
    if (security_event_force_close($mac, $security_event->{security_event_id})) {
        pf::enforcement::reevaluate_access($mac, "admin_modify");
        $result = 1;
    }

    unless ($result) {
        return $self->render_error(500, "Unable to close security event");
    }

    return $self->render(json => {}, status => 200);
}

=head2 create_error_msg

create_error_msg

=cut

sub create_error_msg {
    my ($self, $obj) = @_;
    return "There's already a node with this MAC address"
}

=head2 bulk_reevaluate_access

bulk_reevaluate_access

=cut

sub bulk_reevaluate_access {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my ($indexes, $results) = bulk_init_results($items);
    for my $mac (@$items) {
        my $result = pf::enforcement::reevaluate_access($mac, "admin_modify");
        $results->[$indexes->{$mac}]{status} = $result ? "success" : "failed";
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 bulk_fingerbank_refresh

bulk_fingerbank_refresh

=cut

sub bulk_fingerbank_refresh {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my ($indexes, $results) = bulk_init_results($items);
    for my $mac (@$items) {
        my $result = pf::fingerbank::process($mac, $TRUE);
        $results->[$indexes->{$mac}]{status} = $result ? "success" : "failed";
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 post_update

post_update

=cut

sub post_update {
    my ($self, $updated_data) = @_;
    my $old_node = $self->item;
    if (!exists $updated_data->{category_id} && !exists $updated_data->{status}) {
        return;
    }

    if ($updated_data->{category_id} ne $old_node->{category_id} || $updated_data->{status} ne $old_node->{status}) {
        pf::enforcement::reevaluate_access($self->id, "admin_modify");
    }

    return ;
}

=head2 bulk_restart_switchport

bulk_restart_switchport

=cut

sub bulk_restart_switchport {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my ($indexes, $results) = bulk_init_results($items);
    for my $mac (@$items) {
        my ($status, $msg) = $self->do_restart_switchport($mac);
        if (is_error($status)) {
            if ($STATUS::INTERNAL_SERVER_ERROR == $status) {
                $results->[$indexes->{$mac}]{status} = "failed";
            }

            $results->[$indexes->{$mac}]{message} = $msg;
        } else {
            $results->[$indexes->{$mac}]{status} = "success";
        }
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 bulk_apply_security_event

bulk_apply_security_event

=cut

sub bulk_apply_security_event {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my $security_event_id = $data->{security_event_id};
    my ($indexes, $results) = bulk_init_results($items);
    for my $mac (@$items) {
        my ($last_id) = security_event_add($mac, $security_event_id, ( 'force' => $TRUE ));
        $results->[$indexes->{$mac}]{status} = $last_id > 0 ? "success" : "failed";
    }

    return $self->render( status => 200, json => { items => $results } );
}

=head2 apply_security_event

apply_security_event

=cut

sub apply_security_event {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }
    my $mac = $self->id;
    my $security_event_id = $data->{security_event_id};
    my ($last_id) = security_event_add($mac, $security_event_id, ( 'force' => $TRUE ));

    return $self->render(status => 200, json => { security_event_id => $last_id });
}

=head2 bulk_apply_role

bulk_apply_role

=cut

sub bulk_apply_role {
    my ($self) = @_;
    return $self->do_bulk_update_field('category_id');
}

=head2 bulk_apply_bypass_role

bulk_apply_bypass_role

=cut

sub bulk_apply_bypass_role {
    my ($self) = @_;
    return $self->do_bulk_update_field('bypass_role_id');
}

=head2 bulk_apply_bypass_vlan

bulk update bypass_vlan

=cut

sub bulk_apply_bypass_vlan {
    my ($self) = @_;
    return $self->do_bulk_update_field('bypass_vlan');
}

=head2 do_bulk_update_field

do_bulk_update_field

=cut

sub do_bulk_update_field {
    my ($self, $field) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my $value = $data->{$field};
    ($status, my $iter) = $self->dal->search(
        -columns => [qw(mac)],
        -where => {
            mac => { -in => $items },
            $field => [ {"!=" => $value}, defined $value ? ({"=" => undef} ) : () ],
        },
        -from => $self->dal->table,
        -with_class => undef,
    );
    if (is_error($status)) {
        return $self->render_error($status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items);
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $mac = $node->{mac};
        my $result = node_modify($mac, $field => $value);
        if ($result) {
            $results->[$indexes->{$mac}]{status} = "success";
            pf::enforcement::reevaluate_access($mac, "admin_modify");
        } else {
            $results->[$indexes->{$mac}]{status} = "failed";
        }
    }

    return $self->render( status => 200, json => { items => $results } );
}

=head2 restart_switchport

restart_switchport

=cut

sub restart_switchport {
    my ($self) = @_;
    my $mac = $self->id;
    my ($status, $msg) = $self->do_restart_switchport($mac);
    if (is_error($status)) {
        return $self->render_error($status, $msg);
    }

    return $self->render(json => {}, status => 200);
}

=head2 do_restart_switchport

do_restart_switchport

=cut

sub do_restart_switchport {
    my ($self, $mac) = @_;
    my $ll = locationlog_view_open_mac($mac);
    unless ($ll) {
        return ($STATUS::NOT_FOUND, "Unable to find node location.");
    }

    my $connection = pf::Connection->new;
    $connection->backwardCompatibleToAttributes($ll->{connection_type});
    unless ($connection->transport eq "Wired") {
        return ($STATUS::UNPROCESSABLE_ENTITY, "Trying to restart the port of a non-wired connection");
    }

    my $switch = pf::SwitchFactory->instantiate($ll->{switch});
    unless ($switch) {
        return ($STATUS::NOT_FOUND, "Unable to instantiate switch $ll->{switch}");
    }

    unless ($switch->bouncePort($ll->{port})) {
        return ($STATUS::INTERNAL_SERVER_ERROR, "Couldn't restart port.");
    }

    return ($STATUS::OK, "");
}

=head2 reevaluate_access

reevaluate_access

=cut

sub reevaluate_access {
    my ($self) = @_;
    my $mac = $self->id;
    my $result = pf::enforcement::reevaluate_access($mac, "admin_modify");
    unless ($result) {
        return $self->render_error($STATUS::UNPROCESSABLE_ENTITY, "unable reevaluate access for $mac");
    }

    return $self->render(json => {}, status => 200);
}

=head2 rapid7

rapid7

=cut

sub rapid7 {
    my ($self) = @_;
    my $mac = $self->id;
    my $scan = pf::Connection::ProfileFactory->instantiate($mac)->findScan($mac);
    unless ($scan && $scan->isa("pf::scan::rapid7")) {
        return $self->render_error(404, "No rapid7 scan engine for $mac");
    }

    my $ip = pf::ip4log::mac2ip($mac);
    return $self->render(
        json => {
            ip => $ip,
            item => $scan->assetDetails($ip),
            device_profiling => $scan->deviceProfiling($ip),
            top_vulnerabilities => $scan->assetTopVulnerabilities($ip),
            last_scan => $scan->lastScan($ip),
            scan_templates => $scan->listScanTemplates(),
    });
}

=head2 security_events

security_events

=cut

sub security_events {
    my ($self) = @_;
    my $mac = $self->id;
    my @security_events = eval {
        map { $_->{release_date} = '' if ($_->{release_date} eq '0000-00-00 00:00:00'); $_ } security_event_view_open($mac)
    };
    if ($@) {
        return $self->render_error(500, "Can't fetch security events from database.");
    }

    return $self->render(json => { items => \@security_events });
}

=head2 park

park

=cut

sub park {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }
    my $mac = $self->id;
    my $ip = $data->{ip};
    pf::parking::park($mac, $ip);
    return $self->render(json => {});
}

=head2 unpark

unpark

=cut

sub unpark {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }
    my $mac = $self->id;
    my $ip = $data->{ip};
    my $results = pf::parking::unpark($mac, $ip);
    if (!$results) {
        return $self->render_error(422, "Cannot unpark $mac");
    }

    return $self->render(json => {}, status => 200);
}

=head2 network_graph

network_graph

=cut

sub network_graph {
    my ($self) = @_;
    my ($status, $search_info_or_error) = $self->build_network_graph_info();
    if (is_error($status)) {
        return $self->render(json => $search_info_or_error, status => $status);
    }

    ($status, my $response) = $self->network_graph_search_builder->search($search_info_or_error);
    if ( is_error($status) ) {
        return $self->render_error(
            $status,
            $response->{message},
            $response->{errors}
        );
    }
    ($status, my $network_graph) = $self->map_to_network_graph($search_info_or_error, $response);
    if ( is_error($status) ) {
        return $self->render_error(
            $status,
            $network_graph->{message},
            $network_graph->{errors}
        );
    }

    delete $response->{items};
    $response->{network_graph} = $network_graph;

    return $self->render(
        json   =>  $response,
        status => $status
    );
}

=head2 build_network_graph_info

build_network_graph_info

=cut

sub build_network_graph_info {
    my ($self) = @_;
    my ($status, $search_info_or_error) = $self->build_search_info;
    if (is_error($status)) {
        return $status, $search_info_or_error;
    }

    my $fields = $search_info_or_error->{fields};
    my ($switch_fields, $db_fields) = part { /^switch\./ ? 0 : 1 } @$fields;
    s/^node\.// for @$db_fields;
    $search_info_or_error->{fields} = $db_fields;
    $search_info_or_error->{switch_fields} = $switch_fields;
    return $status, $search_info_or_error;
}

=head2 network_graph_search_builder

network_graph_search_builder

=cut

sub network_graph_search_builder {
    return pf::UnifiedApi::Search::Builder::NodesNetworkGraph->new(); 
}

=head2 pf_network_graph_node

pf_network_graph_node

=cut

sub pf_network_graph_node {
    my ($self, $response) = @_;
    return {
        "type" => "packetfence",
        "id" => "packetfence",
    };
}

=head2 map_to_network_graph

map_to_network_graph

=cut

sub map_to_network_graph {
    my ($self, $search_info, $response) = @_;
    my @nodes = (
        $self->pf_network_graph_node($response),
    );
    $search_info->{switch_group_found} = {};
    $search_info->{switches_found} = {};
    my @links;
    my %network_graph = (
      type => "NetworkGraph",
      label => "PacketFence NetworkGraph",
      protocol => "OLSR",
      version => "9.01",
      metric => undef,
      nodes => \@nodes,
      links => \@links,
    );
    for my $node (@{$response->{items}}) {
        my $id = $node->{mac};
        push @nodes, {
            id => $id,
            type => "node",
            properties => $node,
        };

        my $switch_id = $node->{"locationlog.switch"} // "unknown";
        push @links, { source => $switch_id, target => $id };
        $self->add_switch_to_network_graph($search_info, \%network_graph, $switch_id);
    }

    return 200, \%network_graph;
}


=head2 add_switch_to_network_graph

add_switch_to_network_graph

=cut

sub add_switch_to_network_graph {
    my ($self, $search_info, $network_graph, $switch_id) = @_;
    my $switches_found = $search_info->{switches_found};
    if (!exists $switches_found->{$switch_id}) {
        my ($switch, $link, $group) = $self->pf_network_graph_switch_info($search_info, $network_graph, $switch_id);
        push @{$network_graph->{nodes}}, $switch;
        push @{$network_graph->{links}}, $link;
        $switches_found->{$switch_id} = undef;
        $self->add_swith_group_to_network_graph($search_info, $network_graph, $group);
    }
}

=head2 add_swith_group_to_network_graph

add_swith_group_to_network_graph

=cut

sub add_swith_group_to_network_graph {
    my ($self, $search_info, $network_graph, $group) = @_;
    return unless defined $group;
    my $switch_group_found = $search_info->{switch_group_found};
    my $id = $group->{id};
    if (!exists $switch_group_found->{$id} ) {
        push @{$network_graph->{nodes}}, $group;
        push @{$network_graph->{links}}, { source => "packetfence", "target" => $id };
        $switch_group_found->{$id} = undef;
    }
}

=head2 pf_network_graph_switch_info

pf_network_graph_switch_info

=cut

sub pf_network_graph_switch_info {
    my ($self, $search_info, $network_graph, $switch_id) = @_;
    my %switch = ( id => $switch_id, type => "switch" );
    my %link = ( source => "packetfence", "target" => $switch_id );
    if ( $switch_id eq "unknown" ) {
        $switch{type} = "unknown";
        return (\%switch, \%link, undef);
    }

    my $cfg = get_switch_data($switch_id);
    if (defined $cfg) {
        my %properties;
        $switch{properties} = \%properties;
        for my $field ( @{ $search_info->{switch_fields} } ) {
            $field =~ s/^switch\.//;
            $properties{$field} = exists $cfg->{$field} ? $cfg->{$field} : undef;
        }
        my $group_id = ($cfg->{group} // "default" ) . "-group";
        $link{source} = $group_id;
        my %group = ( "id" => $group_id , type => "switch-group" );
        return (\%switch, \%link, \%group);
    }

    return (\%switch, \%link, undef);
}


=head2 get_switch_data

get_switch_data

=cut

sub get_switch_data {
    my ($switch_id) = @_;
    if (exists $pf::SwitchFactory::SwitchConfig{$switch_id}) {
        return $pf::SwitchFactory::SwitchConfig{$switch_id};
    }

    return undef unless valid_ip($switch_id);
    my $ip = NetAddr::IP->new($switch_id);
    if (my $rangeConfig = first { $ip->within($_->[0]) } @pf::SwitchFactory::SwitchRanges) {
        return $pf::SwitchFactory::SwitchConfig{$rangeConfig->[1]};
    }

    return undef;
}

=head2 bulk_import

bulk_import

=cut

sub bulk_import {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my $count = @$items;
    if ($count == 0) {
        return $self->render(json => { items => [] });
    }

    my $stopOnError = $data->{stopOnFirstError};
    my @results;
    $#results = $count - 1;
    my $i;
    for ($i=0;$i<$count;$i++) {
        my $result = $self->import_item($data, $items->[$i]);
        $results[$i] = $result;
        $status = $result->{status} // 200;
        if ($stopOnError && $status == 422) {
            $i++;
            last;
        }
    }

    for (;$i<$count;$i++) {
        my $item = $items->[$i];
        my $result = { item => $item, status => 424, message => "Skipped" };
        $results[$i] =  $result;
        my @errors = $self->import_item_check_for_errors($data, $item);
        if (@errors) {
            $result->{errors} = \@errors;
        }
    }

    return $self->render(json => { items => \@results });
}

sub import_item {
    my ($self, $request, $item) = @_;
    my @errors = $self->import_item_check_for_errors($request, $item);
    if (@errors) {
        return { item => $item, errors => \@errors, message => 'Cannot save node', status => 422 };
    }

    my $logger = get_logger();
    my $mac = $item->{mac};
    my $pid = $item->{pid} || $default_pid;
    my $node = node_view($mac);
    if ($node) {
        if ($request->{ignoreUpdateIfExists}) {
            return { item => $item, status => 409, message => "Skip already exists", isNew => $self->json_false} ;
        }
    } else {
        if ($request->{ignoreInsertIfNotExists}) {
            return { item => $item, status => 404, message => "Skip does not exists", isNew => $self->json_true} ;
        }
    }

    if (!defined($node) || (ref($node) eq 'HASH' && $node->{'status'} ne $pf::node::STATUS_REGISTERED)) {
        $logger->debug("Register MAC $mac ($pid)");
        (my $result, my $msg) = node_register($mac, $pid, %$item);
    } else {
        $logger->debug("Modify already registered MAC $mac ($pid)");
        my $result = node_modify($mac, %$item);
        node_update_last_seen($mac);
    }

    return { item => $item, status => 200, isNew => ( defined $node ? $self->json_false : $self->json_true ) };
}

sub import_item_check_for_errors {
    my ($self, $request, $item) = @_;
    my @errors;
    my $mac = $item->{mac};
    my $logger = get_logger();
    if (!$mac || !valid_mac($mac)) {
        my $message = defined $mac ? "Invalid MAC" : "MAC is a required field";
        $logger->debug($message);
        push @errors, { field => "mac", message => $message };
    }

    my $pid = $item->{pid};
    if ($pid) {
        if($pid !~ /$pf::person::PID_RE/) {
            my $message = "Invalid PID ($pid)";
            $logger->debug($message);
            push @errors, { field => "pid", message => $message };
        }
    }

    return @errors;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;
