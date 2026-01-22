# sunset

Smart home lighting controller that adjusts Tapo smart bulbs based on time of day, sunrise/sunset, home occupancy, and device activity.

## Features

- **Time-based color adjustment**: Transitions light color smoothly throughout the day (warm at sunrise/sunset, cool during day)
- **Occupancy detection**: Pings your phone to detect if you're home
- **Activity detection**: Monitors smart plug power usage (e.g., PS5, appliances) to trigger automatic lighting
- **Brightness control**: Adjusts brightness based on daytime vs nighttime, occupancy, and activity
- **Kitchen automation**: Auto-controls kitchen light based on presence and time of day
- **Debug mode**: Run with `-c perl` to see what decisions the script is making

## Requirements

- Perl 5.10+
- `DateTime::Event::Sunrise` - Calculate sunrise/sunset times
- `Math::Round` - Rounding support
- `Net::Ping` - Check if phone is home
- `kasa` command-line tool - Control Tapo devices (install via `pip install kasa`)

## Installation

1. Clone or copy `sunset.pl` to a location in your `$PATH` or a cron-accessible directory
2. Make it executable:
   ```bash
   chmod +x sunset.pl
   ```

3. Create credentials file at `~/.config/sunset.env`:
   ```bash
   export TAPO_USERNAME="your_email@example.com"
   export TAPO_PASSWORD="your_password"
   ```
   
4. Secure the credentials file:
   ```bash
   chmod 600 ~/.config/sunset.env
   ```

## Configuration

Edit the variables at the top of `sunset.pl`:

- `$bulb_ip_office` - IP address of office bulb (default: `192.168.100.39`)
- `$bulb_ip_livingroom` - IP address of living room bulb (default: `192.168.100.16`)
- `$wimpy_power_ip` - IP of wimpy power monitor (default: `192.168.100.95`)
- `$ps5_power_ip` - IP of PS5 power monitor (default: `192.168.100.6`)
- `$kitchen_ip` - IP of kitchen light (default: `192.168.100.99`)
- `$phone_ip` - IP address of your phone for presence detection (default: `192.168.100.56`)
- `$longitude`, `$latitude` - Your location (default: `101, 3`)

Constants:
- `DAYTIME_BRIGHTNESS_MOD` - How much darker to make lights during day (default: 49)
- `IN_ROOM_MOD` - How much brighter when someone is actively using a room (default: 50)
- `IS_HOME_BRIGHTNESS_MOD` - How much darker when no one is home (default: 49)

## Usage

### Basic run (with environment variables):
```bash
source ~/.config/sunset.env
./sunset.pl
```

### From cron (every minute):
Create a wrapper script `/home/karl/bin/sunset/run_sunset.sh`:
```bash
#!/bin/bash
source ~/.config/sunset.env
exec /home/karl/bin/sunset/sunset.pl
```

Make it executable and add to crontab:
```bash
chmod +x /home/karl/bin/sunset/run_sunset.sh
crontab -e
```

Add the line:
```
* * * * * /home/karl/bin/sunset/run_sunset.sh
```

### Debug output:
When run from a TTY, the script prints debug information showing:
- Whether you're home (via phone ping)
- Current power usage of monitors
- Hue, saturation, and brightness being set
- Which lights are being controlled

## How it works

### Time-of-day color transitions

- **0-6 AM**: Deep red to orange (hue 0→260, saturation 100)
- **6 AM-12 PM**: Orange to yellow fading to white (hue 260→0, saturation 100→0)
- **12 PM-6 PM**: White to soft yellow (hue 0→50, saturation 0→100)
- **6 PM-midnight**: Yellow to deep red (hue 50→0, saturation 100)

### Brightness adjustments

- **Daytime**: Reduced by `DAYTIME_BRIGHTNESS_MOD` (49 points)
- **Not home**: Reduced by `IS_HOME_BRIGHTNESS_MOD` (49 points)
- **Active devices** (power > threshold): Increased by `IN_ROOM_MOD` (50 points)
- **Range**: Clamped between 1-100

### Presence detection

- Pings your phone every run (3 retries, 2 second timeout)
- If any ping succeeds, you're marked as home
- Power usage monitors can also override this (if active, you're home)

### Kitchen light

Turns on when:
- You're home AND it's night AND after 6 PM, OR
- PS5 is active (>50W) AND it's night

Turns off otherwise.

## Troubleshooting

### "Error: Using authentication requires both --username and --password"
Make sure environment variables are set:
```bash
export TAPO_USERNAME="your_email"
export TAPO_PASSWORD="your_password"
./sunset.pl
```

### "Unable to set the lamp color"
Check that:
- The bulb IP addresses are correct and reachable
- The kasa CLI tool is installed and working
- Your credentials are correct
- The bulbs are online and powered on

### Lights not responding
Test kasa CLI directly:
```bash
kasa --host 192.168.100.39 --username your_email --password your_password on
```

## Notes

- Run frequently (every minute via cron) for smooth transitions
- Phone presence detection works best with a static IP on your device
- Power monitors need to support the kasa CLI protocol
- Credentials are stored in plaintext in `~/.config/sunset.env`—keep the file permissions restricted
