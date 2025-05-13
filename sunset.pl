#!/usr/bin/perl

use DateTime;
use DateTime::Event::Sunrise;
use Math::Round;
use Net::Ping;
use Env qw($TAPO_USERNAME $TAPO_PASSWORD);
use strict;


my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

my $bulb_ip_office = "192.168.100.39";
my $bulb_ip_livingroom = "192.168.100.16";
my $wimpy_power_ip = "192.168.100.5";
my $ps5_power_ip = "192.168.100.6";

my $longitude = 101;
my $latitude = 3;

my $brightness = "50";
my $daytime_brightness_mod = 49;
my $in_room_mod = 50;
my $hue = 0;
my $saturation = 100;
my $minute_of_day = (( $hour * 60 ) + $min ); # 0 - 1440

my $wimpy_power = 0;
my $ps5_power = 0;
my $wimpy_power_inroom_trigger = 160;
my $ps5_power_inroom_trigger = 50;
my $set_lamp_office = "";
my $set_lamp_livingroom = "";

my $tty=istty();
print "Found a TTY, printing debug.\n" if $tty;

my $dt = DateTime->now;             
my $sunrise = DateTime::Event::Sunrise ->sunrise ( longitude =>$longitude, latitude  =>$latitude, );
my $sunset = DateTime::Event::Sunrise ->sunset ( longitude =>$longitude, latitude  =>$latitude, ); 

$hour = int ($hour);
# is it day or night?
my $day_set = DateTime::SpanSet->from_sets(
  start_set => $sunrise, end_set => $sunset );
my $is_it_day = $day_set->contains( $dt ) ? '1' : '0';

# 0 - 6
if (( $hour >= 0 ) and( $hour < 6 )) {
  $hue = round (( $minute_of_day / 360 ) * 260 );  # between 0 and 260 
  $saturation = 100;
} elsif (( $hour >= 6 ) and ( $hour < 12 )) {
  $hue = ( ((( $minute_of_day - 360 ) / 360 ) * 100 - 100 ) * -1 ); # Get precent remaining of 260, number needs to be between 260 and 0
  $hue = round (( 260  / 100 * $hue ));
  $saturation = round ( $hue / 2.6 ) ; # between 100 to 0
} elsif (( $hour >= 12 ) and ($hour < 18 )) {
  $hue = round((( $minute_of_day - 720 ) / 360 ) * 50); # between 0 and 50 
  $saturation = round((( $minute_of_day - 720 ) / 360 ) * 100); # between 0 - and 100
} else {
  $hue = ((( $minute_of_day - 1080 ) / 360 * 100 - 100 ) * -1 ); # between 50 and 0 
  $hue = round (( 50  / 100 * $hue ));
  $saturation = 100;
}

print "Make the light a bit brighter it is nighttime.\n" if ( $tty );
if ( $is_it_day ) { $brightness = $brightness - $daytime_brightness_mod; }

$wimpy_power = get_power_usage ($wimpy_power_ip, $TAPO_USERNAME, $TAPO_PASSWORD);
$ps5_power = get_power_usage ($ps5_power_ip, $TAPO_USERNAME, $TAPO_PASSWORD);

print "Wimpy current power usage is $wimpy_power W > $wimpy_power_inroom_trigger W threshold for in use and brightness is $brightness\n" if ( $tty );

if ( $wimpy_power > $wimpy_power_inroom_trigger )  { 
  $brightness = $brightness + $in_room_mod; 
}

if ( $brightness > 100 ) { $brightness = 100; }
if ( $brightness < 1 ) { $brightness = 1; }

if ( $tty ) { 
	print "Wimpy Power is $wimpy_power W and daytime is $is_it_day, PS5 Power is $ps5_power W. Is it day? $is_it_day \n";
};

set_lamp_colour ($bulb_ip_office, $TAPO_USERNAME, $TAPO_PASSWORD, $hue, $saturation, $brightness);

$brightness = 50;
print "Make the light a bit brighter it is nighttime.\n" if ( $tty );
if ( $is_it_day ) { $brightness = $brightness - $daytime_brightness_mod; }

print "PS5 $ps5_power W >  $ps5_power_inroom_trigger threshold and brightness is $brightness\n" if ( $tty );

if ( $ps5_power > $ps5_power_inroom_trigger )  { 
  $brightness = $brightness + $in_room_mod; 
}

if ( $brightness > 100 ) { $brightness = 100; }
if ( $brightness < 1 ) { $brightness = 1; }

set_lamp_colour ($bulb_ip_livingroom, $TAPO_USERNAME, $TAPO_PASSWORD, $hue, $saturation, $brightness);

sub get_power_usage {
    my ($device_ip, $username, $password) = @_;

    # Run the kasa command to get power usage
    my $command_output = `/usr/local/bin/kasa --host $device_ip --username $username --password $password`;

    # Check if the command was successful
    if ($? != 0) {
        my $exit_code = $? >> 8;
        print "Error: Unable to get power usage from device at $device_ip (Exit code: $exit_code).\n";
        return undef; # Return undefined on failure
    }

    # Extract power usage from the command output
    if ($command_output =~ /(\d+\.?\d*)\s*W/) {
        return $1; # Return the power usage in watts
    } else {
        print "Error: Unable to parse power usage from device at $device_ip.\n";
        return undef; # Return undefined if parsing fails
    }
}

sub set_lamp_colour {
    my ($device_ip, $username, $password, $hue, $saturation, $brightness) = @_;

    # Run the kasa command to set the lamp color
    print "$device_ip Hue, Saturation and Brightness is $hue $saturation $brightness\n" if ( $tty );
    my $command_output = `/usr/local/bin/kasa --host $device_ip --username $username --password $password hsv $hue $saturation $brightness`;

    # Check if the command was successful
    if ($? != 0) {
        my $exit_code = $? >> 8;
        print "Error: Unable to set the lamp color (Exit code: $exit_code).\n" if ( $tty );
        return undef; # Return undefined on failure
    }
    return 1; # Return success
}

sub istty {
  if ( -t STDIN ) { return 1 } else { return 0 };
}
