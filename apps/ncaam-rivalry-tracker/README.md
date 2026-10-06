##NCAA College Basketball Rivalry Tracker – Glance

Display head-to-head series records, AP rankings, last game results, active winning streaks, and upcoming matchup dates for any two Division I men's college basketball teams on a wide LED panel.

Version 1.0 · App ID: ncaam-rivalry-tracker
By SlaterDen

#App Settings
Setting	Required	Description
CFBD API Key	Yes	Your free key from CollegeFootballData.com. The same key works for basketball data, so there is no separate signup.
Team 1	Yes	First school, picked from a dropdown of all D1 teams (default: Duke)
Team 2	Yes	Second school, picked from the same dropdown (default: North Carolina)
Team Name Length	Yes	Abbreviations (e.g. DUKE, UNC) or Full Name (long names are clipped to fit the team chip)
#How to Get Your API Key
Go to CollegeFootballData.com.
Create a free account or sign in.
Generate your API key and paste it into the Glance app settings as CFBD API Key.

Without a key the panel shows a sample Duke vs. North Carolina screen labeled DEMO.

#Screens & Layout

The app is a single page (main) designed for a 192×32 panel, with a 10 px safe zone on each side.

Screen	What's shown
Series view	Team chips in team colors at the top corners with the rivalry name centered between them. Below, each team's all-time win total in large digits flanks a split-color progress bar. AP rank (#4) and active win streak (W3) sit beside each team's total. A white tick above the bar marks the midpoint, so you can see who leads at a glance.
First meeting	Shown when no games between the two teams are found. Displays FIRST MEETING with any rankings and the next scheduled date.
Demo	Sample data, labeled DEMO, shown until an API key is entered.
#Bottom Row
LAST: Most recent result, winner listed first (e.g. DUKE 74-71).
SINCE: Earliest season in the data the series is counted from (e.g. SINCE 2003). It is hidden when there isn't room.
NEXT: Date of the next scheduled game, LIVE if a game is in progress, or TBD.
#Rivalry Names

Matchups with a known rivalry show its name in gold, for example Tobacco Road (Duke–UNC), Bedlam (Oklahoma–Oklahoma State), Red River Rivalry (Oklahoma–Texas), and The Holy War (BYU–Utah). Other pairs show ALL-TIME SERIES. Long names fall back to shorter versions when they don't fit between the team chips.

#Data Sources
Source	Used for
College Basketball Data API (api.collegebasketballdata.com)	Game history (used to tally the series), team names, abbreviations, colors, schedules, and AP rankings

The series record is calculated by the app from each team's game history rather than fetched as a single stat. It counts the games the API has, which may not reach back to the first meeting of an older rivalry. The SINCE label shows how far back the count goes.

Rankings show only from November through April. In the offseason they are hidden so last season's final poll isn't mistaken for a current one.

This app is not affiliated with the NCAA or CollegeFootballData.com. All sports data remains the property of its respective providers.

#Errors & Troubleshooting
What you see	Likely cause	What to try
DEMO (Duke vs. UNC sample)	No API key entered	Add your key in the app settings
PICK TWO DIFFERENT TEAMS	Team 1 and Team 2 are the same	Choose two different schools
API KEY REJECTED	Key is wrong, expired, or not accepted by the basketball API	Re-check the key in settings or generate a new one
TEAM NOT RECOGNIZED	A selected school isn't in the API's current team list	Pick both teams again; if it persists, report the school name so the dropdown can be corrected
API LIMIT REACHED	Too many requests on the key	Try again later
API UNAVAILABLE	Network issue or API outage	Try again later
FIRST MEETING	No games between the teams in the available data	Normal for teams that haven't played, or for series older than the data coverage
#Notes
Panel: designed for 192×32 wide LED panels.
Refresh: once a day. Series data is cached for 24 hours and rankings for 6 hours, so new results appear the next day.
Dates are shifted from UTC to approximate US time so evening tip-offs show the correct day.
Credits

SlaterDen · Built for the Glance Developer Network.