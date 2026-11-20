# DUSTEX Fishing

Tides, weather, seas, moon and feeding times, a bite forecast, alerts and local fishing reports on one screen, for iPhone, iPad and the DUSTEX desktop.

**Open the app:** https://deesayi.github.io/dustex-fishing/

## The screen at a glance

**NOW** shows the current weather, feels-like temperature and humidity, sunrise and sunset, plus water temperature and swell direction on the coast (water temperature and lake level in lake mode).

**TOMORROW** shows the high and low, sky, strongest wind and gusts, chance of rain, and the biggest seas offshore (or the latest water temperature in lake mode).

**The four gauges:** **Barometer** in inches of mercury, with its 3-hour trend (falling, steady or rising). **Wind** in mph; the thin red needle marks the gusts. **Seas** in feet with the wave period in seconds (on a lake this gauge becomes **Water °F**). The **compass** points to where the wind is coming from. Green on a dial is good fishing, orange is fair, red is tough.

**Tide charts** cover the next 24 hours for your inshore station (river, bay or intracoastal) and your offshore station (beach, pier or inlet). The red dashed line is now, green dots are high tides and gold dots are low tides. Below each chart: whether the tide is rising or falling, the next high or low, and the next four tides with their heights.

**Moon & Solunar** shows the moon's phase, how much of it is lit and days to the next full or new moon. **Feeding times** are the solunar periods: **Major** periods (2 hours, centered on the moon overhead or underfoot) and **Minor** periods (1 hour, centered on moonrise and moonset). The period you are in now is shown in green.

## Fishing forecast

The bite dials score the fishing right now from 0 to 10: **Poor** below 3, **Fair** 3 to 5, **Good** 5 to 7, **Very good** 7 to 8.5 and **Excellent** above 8.5. There is one dial for **Inshore** and one for **Offshore** (a single **Lake bite** dial in lake mode). The list beside the dials explains the score.

What goes into the score: a slowly falling barometer (fish feed) versus a fast rise after a front (tough bite); wind (light is best); moving tide versus slack water; seas offshore; being inside or near a solunar period; days near the new or full moon (stronger tides); dawn and dusk low light. Thunderstorms pull the score down hard, and seas over 5 ft cap the offshore score. In lake mode, water temperature (55 to 75°F is best), warming or cooling water, and a rising or falling lake level replace the tides and seas.

**Best times today** lists the strongest windows left today. Each solunar period, dawn and dusk is a window; it earns an extra star when it overlaps another window and another when the tide is moving. More stars, better odds.

## Forecast for a future time

**FORECAST FOR**, in the middle of the bottom panel, shows the fishing at another time, up to three days ahead. Pick a **day** from the menu and drag the **time slider**. The bite dials, the reasons and **Best times** then show that day and time, using the hourly forecast for barometer trend, wind, storms and seas, plus the predicted tide, solunar periods, moon phase, and dawn and dusk. The slider track maps the day: the light band is daylight, bright gold marks are major solunar periods and paler marks are minor ones (with a red line for right now on today's track). Press **NOW** to go back to live conditions; a picked time that arrives returns to live by itself.

## Lake mode (freshwater)

When your spot is more than 50 miles from the nearest ocean tide station, the app switches to lake mode by itself. The tide charts become a 3-day **lake level** chart and a 3-day **water temperature** chart from the nearest US Geological Survey gauge within about 25 miles. Small lakes may not have a gauge; the panel says so. You can force either mode in Settings (Water type).

## Fishing reports

Tap **REPORTS** for recent local fishing reports from newspapers, magazines and state wildlife agencies, collected every 4 hours for 65 areas across the country, from the coasts to the Great Lakes and the big inland lakes. The number on the button is how many arrived in the past week. Tap a report to read it. If your spot has no report area within 75 miles, tap **SEARCH THE WEB** for this week's reports.

## Settings

**Search:** type a town, beach, inlet or lake and tap **SEARCH**, then tap the right place in the list. **HERE** uses your device's location (allow it when asked).

**Name shown in the header:** what appears at the top left. Change it to anything you like.

**Tide stations:** the app picks the nearest NOAA stations for you: a river, bay or intracoastal station for **Inshore** and a beach, pier or inlet station for **Offshore**. The lists show the 15 closest with their distances, so you can choose others. Offshore seas come from the offshore station's position.

**Water type:** *Automatic* (lake mode when far from the coast), *Saltwater* or *Freshwater lake*.

**Alerts:** tick **Alert me before good fishing windows**, choose **how early** (15, 30 or 60 minutes) and **which windows** (all, good and up, or best only). A gold banner pops up while the app is open. **ADD NEXT 3 DAYS TO CALENDAR** adds the windows to your calendar with reminders, which alert you even when the app is closed. **TEST ALERT** shows a sample.

**DEFAULTS** puts everything back to Daytona Beach. **CANCEL** closes without changes. **SAVE** applies your changes.

## Keeping it fresh

Weather and seas update every 15 minutes, tides every 3 hours and lake gauges every hour. Tap the **updated** time at the top right to refresh right now. The app keeps a saved copy, so it opens without internet and shows the last tides it loaded. Your settings stay on your device; there is no account and nothing to sign up for.

## Installing and updating

**iPhone and iPad:** open the app's link in Safari, tap **Share** (on the newest devices it's under the three-dots button), then **Add to Home Screen** and **Add**. Open it from the Home Screen icon. On iPad it shows the full panel sideways; on iPhone it is a tall layout you scroll. New versions arrive automatically: close the app and open it twice.

**Desktop widget:** docked into the wallpaper. Right-click it for **Reload**, **Open in browser** or **Close**. It reloads itself every hour.

## Where the data comes from

Weather and seas: [Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0). Tides and stations: NOAA Tides & Currents. Lake level and water temperature: U.S. Geological Survey. Places: Open-Meteo geocoding. Fishing reports: Google News and Bing News search of local outlets. Moon, solunar times and sunrise are calculated on your device. Fishing scores are a guide, not a guarantee; always check official marine forecasts and local regulations before heading out.

## Files in this repository

- `index.html`: the whole app (layout, data, scoring, settings).
- `sw.js`: keeps a saved copy so the app opens offline; bump the version number when you change the app.
- `manifest.webmanifest` and the `icon` / `apple-touch-icon` images: Home Screen name and icon.
- `gauge_*.png`: the chrome gauge faces, glass and DUSTEX cap.
- `reports-places.json`: the fishing report areas (name, position, places to search). Add an area here to cover a new spot.
- `tools/fetch_reports.py` and `.github/workflows/reports.yml`: the job that collects reports into `reports.json` every 4 hours (Actions tab > Fishing reports > Run workflow to run it now).
