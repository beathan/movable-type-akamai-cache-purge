# Akamai Cache Purge Plugin for Movable Type
# Author: Ben Boyd, beathan@gmail.com
package AkamaiCachePurge::Plugin;

use strict;
use SOAP::Lite;
use MT::PluginData;

sub purge_url {
	my ($cb, $app, $obj, $original) = @_;
	
	if($obj->status != 2) { # Return if the post isn't published (nothing to purge)
		return;
	}
	
	# -------------------------------
	# Define global variables
	# -------------------------------
	my ($user, $pwd, $file, $type, $action, $email, $domain, $retval, $key, $val, $message, $results) = '';
	my (@urls, @options);
	my $network = 'ff';
	my $ret_code = '';

	# Load plugin settings
	my $plugin = MT::PluginData->load({plugin => 'AkamaiCachePurge'});

	# Full URL for entry we're purging
	my $entry_url = $obj->archive_url;
	
	# Get entry text and get number of total pages
	my $entry_text = join('', $obj->text, $obj->text_more);
	my @pb_arr = split(/<pb *\/>/i, $entry_text);
	my $num_pages = scalar(@pb_arr);
	
	my $soap = SOAP::Lite->new(proxy => 'https://ccuapi.akamai.com:443/soap/servlet/soap/purge',
							   uri => 'http://ccuapi.akamai.com/purge');

	$action = 'remove';
	$user = $plugin->data->{'akamai_username'};
	$pwd = $plugin->data->{'akamai_password'};
	$email = $plugin->data->{'notification_email'};
	
	# Set @options
	push @options, SOAP::Data->type('string')->value("email-notification=$email");
	push @options, SOAP::Data->type('string')->value("action=$action");

	# Add canonical URL to the urls array
	my $soap_data = SOAP::Data->type('string')->value($entry_url);
	push(@urls, $soap_data);
	
	# Purge any extra pages
	for(my $i = 1; $i <= $num_pages; $i++) {
		$soap_data = SOAP::Data->type('string')->value($entry_url . "?page=${i}");
		push(@urls, $soap_data);		
	}
	
	# Call purgeRequest
	$results = $soap->purgeRequest(SOAP::Data->name("name" => $user),
								   SOAP::Data->name("pwd" => $pwd),
								   SOAP::Data->name("network" => $network),
								   SOAP::Data->name("opt" => [@options]),
								   SOAP::Data->name("uri" => [@urls]));

	my $res = $results->result();
	$message = "Purge request for ${entry_url}, which has ${num_pages} page(s). Result Code: " . $res->{resultCode} . "\n ";
	
	if ($res->{resultCode} =~ m/1\d\d/) {
		$message .= "Purge request completed with message: ". $res->{resultMsg} ."\n";	
	} elsif ($res->{resultCode} =~ m/2\d\d/) {
		$message .= "Purge request accepted with warning: ". $res->{resultMsg} ."\n";	
	} else {
		$message .= "Purge request failed with error: ". $res->{resultMsg} ."\n";	
	}

	# Log event to the MT Activity Log
	MT->log({  
		message => $message,
		class => 'system',
		level => MT::Log::DEBUG(), 
	});

	1;
}

1;
