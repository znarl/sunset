#!/usr/bin/perl

use DateTime::Event::Sunrise;
use Math::Round;
use Net::Ping;
use Env qw($TAPO_USERNAME $TAPO_PASSWORD);
use strict;
use warnings;

my ($sec,$min,$hour) = localtime();

my $bulb_ip_office = "192.168.100.39";
my $bulb_ip_livingroom = "192.168.100.16";
my $wimpy_power_ip = "192.168.100.95";
my $ps5_power_ip = "192.168.100.6";

my $kitchen_ip = "192.168.100.99";

my $phone_address = "48:2C:A0:29:C8:71";
my $phone_ip = "192.168.100.56";
my $ping_retries = 2;
my $ping_timeout = 1;
my $is_home = 0;

my $longitude = 101;
my $latitude = 3;

my $brightness = "50";
my $hue = 0;
my $saturation = 100;
my $minute_of_day = (( $hour * 60 ) + $min ); # 0 - 1440

my $daytime_brightness_mod = 49;
my $in_room_mod = 50;
my $is_home_brightness_mod = 49;

use constant {
  DAYTIME_BRIGHTNESS_MOD => 49,
  IN_ROOM_MOD            => 50,
  IS_HOME_BRIGHTNESS_MOD => 49,
};

my $wimpy_power = 0;
my $ps5_power = 0;
my $wimpy_power_inroom_trigger = 160;
my $ps5_power_inroom_trigger = 50;
my $set_lamp_office = "";
my $set_lamp_livingroom = "";

my $tty=istty();
print "Found a TTY, printing debug.\n" if $tty;

my $ping = Net::Ping->new('tcp');
for my $i (1 .. $ping_retries) {
    if ($ping->ping($phone_ip, $ping_timeout)) {
        $is_home = 1;
        last;
    }
}

print "Is Karl Home? $is_home\n" if ( $tty );

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

print "Make the light a bit brighter if it is nighttime.\n" if ( $tty );
if ( $is_it_day ) { $brightness = $brightness - $daytime_brightness_mod; }

$wimpy_power = get_power_usage ($wimpy_power_ip, $TAPO_USERNAME, $TAPO_PASSWORD);
$ps5_power = get_power_usage ($ps5_power_ip, $TAPO_USERNAME, $TAPO_PASSWORD);

print "Wimpy current power usage is $wimpy_power W > $wimpy_power_inroom_trigger W threshold for in use and brightness is $brightness\n" if ( $tty );

if ( $wimpy_power > $wimpy_power_inroom_trigger )  { 
  $brightness = $brightness + $in_room_mod; 
  $is_home = 1;
}

if ( !$is_home ) {
  $brightness = $brightness - $is_home_brightness_mod;
}

$brightness = clamp($brightness, 1, 100);

if ( $tty ) { 
	print "Wimpy Power is $wimpy_power W and daytime is $is_it_day, PS5 Power is $ps5_power W. Is it day? $is_it_day\n";
};

sub adjust_brightness {
  my ($base, $is_day, $is_home, $power, $trigger) = @_;
  my $b = $base;
  $b -= DAYTIME_BRIGHTNESS_MOD if $is_day;
  $b -= IS_HOME_BRIGHTNESS_MOD unless $is_home;
  $b += IN_ROOM_MOD if $power > $trigger;
  return clamp($b, 1, 100);
}

my $office_brightness = adjust_brightness(50, $is_it_day, $is_home, $wimpy_power, $wimpy_power_inroom_trigger);
set_lamp_colour($bulb_ip_office, $TAPO_USERNAME, $TAPO_PASSWORD, $hue, $saturation, $office_brightness) or warn "Failed to set office lamp color";

my $livingroom_brightness = adjust_brightness(50, $is_it_day, $is_home, $ps5_power, $ps5_power_inroom_trigger);
set_lamp_colour ($bulb_ip_livingroom, $TAPO_USERNAME, $TAPO_PASSWORD, $hue, $saturation, $livingroom_brightness);


sub get_power_usage {
  my ($device_ip) = @_;
  my $cmd = "/usr/local/bin/kasa --host $device_ip --credentials-hash 'QN2Ma+Jg7qEQGiZGHkmurg8ZcVG10ZiIuRUbRHvaRWE=' --encrypt-type 'KLAP' --device-family 'SMART.TAPOPLUG'";
  my $out = qx/$cmd 2>&1/;
  if ($? != 0) { warn "kasa failed for $device_ip: $out"; return 0; }
  if ($out =~ /(\d+(?:\.\d+)?)\s*W/i) { return 0 + $1; }
  warn "cannot parse power for $device_ip: $out";
  return 0;
}


sub set_lamp_colour {
    my ($device_ip, $username, $password, $hue, $saturation, $brightness) = @_;

    # Run the kasa command to set the lamp color
    print "$device_ip Hue, Saturation and Brightness is $hue $saturation $brightness\n" if ( $tty );
    my @cmd = ('/usr/local/bin/kasa', '--host', $device_ip, '--username', $username, '--password', $password, 'hsv', $hue, $saturation, $brightness);
    if ($tty) {
      system(@cmd);
    } else {
      system("@cmd > /dev/null 2>&1");
    }

    # Check if the command was successful
    if ($? != 0) {
        my $exit_code = $? >> 8;
        print "Error: Unable to set the lamp color (exit code: $exit_code).\n" if ( $tty );
        return undef; # Return undefined on failure
    }
    return 1; # Return success
}

sub clamp {
  my ($v, $lo, $hi) = @_;
  return $v < $lo ? $lo : $v > $hi ? $hi : $v;
}

sub istty {
  if ( -t STDIN ) { return 1 } else { return 0 };
}


# Control kitchen light
if ( $is_home && !$is_it_day && $hour > 18 ) {
  print "Karl is home and it is night, turning on the kitchen light.\n" if ( $tty );
  if ($tty) {
    system('/usr/local/bin/kasa', '--host', $kitchen_ip, '--username', $TAPO_USERNAME, '--password', $TAPO_PASSWORD, 'on');
  } else {
    system("/usr/local/bin/kasa --host $kitchen_ip --username $TAPO_USERNAME --password $TAPO_PASSWORD on > /dev/null 2>&1");
  }
} else {
  if ( $ps5_power > $ps5_power_inroom_trigger && !$is_it_day ) {
    if ($tty) {
      system('/usr/local/bin/kasa', '--host', $kitchen_ip, '--username', $TAPO_USERNAME, '--password', $TAPO_PASSWORD, 'on');
    } else {
      system("/usr/local/bin/kasa --host $kitchen_ip --username $TAPO_USERNAME --password $TAPO_PASSWORD on > /dev/null 2>&1");
    }
  } else {
    if ($tty) {
      system('/usr/local/bin/kasa', '--host', $kitchen_ip, '--username', $TAPO_USERNAME, '--password', $TAPO_PASSWORD, 'off');
    } else {
      system("/usr/local/bin/kasa --host $kitchen_ip --username $TAPO_USERNAME --password $TAPO_PASSWORD off > /dev/null 2>&1");
    }
  }
}
