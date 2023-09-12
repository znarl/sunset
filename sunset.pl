#!/usr/bin/perl

use DateTime;
use DateTime::Event::Sunrise;
use Math::Round;
use Net::Ping;
use strict;


my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

my $phone_address = "48:2C:A0:29:C8:71";
my $phone_ip = "192.168.100.9";
my $bulb_ip = "192.168.100.14";
my $wimpy_power_ip = "192.168.100.13";
my $ps5_power_ip = "192.168.100.20";

my $longitude = 101;
my $latitude = 3;

my $brightness = 100;
my $daytime_brightness_mod = 90;
my $in_room_mod = 40;
my $in_room_mod_wimpy = 10;
my $hue = 0;
my $saturation = 100;
my $minute_of_day = (( $hour * 60 ) + $min ); # 0 - 1440

my $ps5_power = 0;
my $wimpy_power = 0;
my $is_home = 0; # assume nope
my $is_home_human = "No";

my $tty;
isatty();
print "Is someone watching?  There is someone! Gotta explain what we are doing as we do it for the humans.\n" if ( $tty );

if ( $tty ) {
  print "I think Karl has been drinking too much and turned off the lamp again.\n" unless pingecho($bulb_ip);
  print "Wimpy Power is cut?  And I am running?  How is this possible?  Call Xfiles team!\n" unless pingecho($wimpy_power_ip);
  print "Playstation power is cut?  Someone playing too long?\n" unless pingecho($ps5_power_ip);
};

print "So when is sunrise and sunset today anyway?. Checking the library...\n" if ( $tty );
my $dt = DateTime->now;             
my $sunrise = DateTime::Event::Sunrise ->sunrise ( longitude =>$longitude, latitude  =>$latitude, );
my $sunset = DateTime::Event::Sunrise ->sunset ( longitude =>$longitude, latitude  =>$latitude, ); 
print "Great, got that figured out now. Just not saying when yet. Yeah, I am sometimes secretive.\n" if ( $tty );

print "So next we gotta figure out if it is day or night knowing the current time and sunset and sunrise times...\n" if ( $tty );
$hour = int ($hour);
# is it day or night?
my $day_set = DateTime::SpanSet->from_sets(
  start_set => $sunrise, end_set => $sunset );
my $is_it_day = $day_set->contains( $dt ) ? '1' : '0';
print "So 1 means day and 0 means night.  That makes it now a $is_it_day.\n" if ( $tty );

print "Is anyone home anyway?  Looking for Karls phone...\n" if ( $tty );
if ( pingecho($phone_ip) ) {
  $is_home = 1;
  $is_home_human = "Yes";
}
print "The answer to the question of is Karl is at home is $is_home_human, or $is_home in binary computer speak.\n" if ( $tty );

print "Next the complex bit, gotta work out what time of day it is and what colour we need to set.\n" if ( $tty );
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

print "Now to make the light a bit brighter if it is day time or not.\n" if ( $tty );
if ( $is_it_day ) { $brightness = $brightness - $daytime_brightness_mod; }

print "Checking the power usage of Wimpy by asking the power supply monitor...\n" if ( $tty );
my $kasa_wimpypower = `/usr/local/bin/kasa --type plug --host  $wimpy_power_ip`;
#if ( $kasa_wimpypower =~ m/'power': (\d*\.?\d*)/ ) { $wimpy_power = $1; }
if ( $kasa_wimpypower =~ m/power=(\d*\.?\d*) voltage=(\d*\.?\d*)/ ) { $wimpy_power = round ( $1 ); }


print "Now I need to ask the power usage monitor on the PS5 power supply how much power it is using...\n" if ( $tty );
my $kasa_ps5power = `/usr/local/bin/kasa --type plug --host  $ps5_power_ip`;
if ( $kasa_ps5power =~ m/power=(\d*\.?\d*) voltage=(\d*\.?\d*)/ ) { $ps5_power = round ( $1 ); }

print "Figuring out, going by the powerusage of the Wimpy at $wimpy_power and PS5 at $ps5_power, if we think someone is in the room...\n" if ( $tty );
if (( $wimpy_power > 160 ) || ( $ps5_power > 5000 ) ) { 
  $brightness = $brightness + $in_room_mod_wimpy; 
  $is_home = 1;
}

if ( $tty ) { 
	print "So, in summary, here is what we know:\n";
	print "* PS5 Power in milliwatts is $ps5_power\n";
	print "* Wimpy Power in watts is $wimpy_power\n";
	print "* That is it daytime in computer speak is $is_it_day\n";
	print "* That $is_home_human is the answer to if Karl is at home\n";
	print "In conclusion I think the Hue, Saturation and Brightness values for lamp need to be set to $hue $saturation $brightness\n";
	print "Is someone home? $is_home_human! So turning lamp off if no one is home or setting the lamp colours and brightness if someone is home.\n";
};

print "Finally, time to talk with the lamp and tell it what to do based on above...\n" if ( $tty );
if ( $brightness > 100 ) { $brightness = 100; }
if ( $is_home > 0 ) {
  `/usr/local/bin/kasa --type bulb --host $bulb_ip hsv $hue $saturation $brightness`;
} else {
  `/usr/local/bin/kasa --type bulb --host $bulb_ip off`;
}

sub isatty() { 
  no autodie; 
  return open($tty, '+<', '/dev/tty'); 
}
