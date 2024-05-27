# EMF Live Viewdata System

This is a Viewdata service for Electromagnetic Field 2024, based on John Newcombe's Telstar system.  It's very much a spare-time project that I originally started putting together so that I could have a Viewdata terminal in my tent, but there has been sufficient interest from other attendees that it'll be made generally available thanks to CuTEL.  It may also be on display in the ECHQ marquee if our terminals hold out!

## Frame Organisation

- `0`: Main index (Telstar default, is a redirect to `9`, can be overridden in config but terminal might send `*0#` from a dedicated key? Check this!)
- `1`: Schedule
    - `10n`: Schedule listings for group `n`; currently follow-on frames are used but changing to explictly numbered frames would allow better routing?  If so, root entry should redirect to first page.
    - `11n`: Individual event listing entries for group `n`; having duplicates by group allows for per-group prev/next routing. Standard follow-on frames where multiple pages are needed.
    - Groups `n` are:
        - `0`: All events
        - `1` - `3`: Friday - Sunday schedules (by logical day)
        - `4` - `6`: Stages A - C schedules
        - `7`: Workshop schedules (should this include only venues matching `/Workshop/` or does it include all events of type `workshop` or `youthworkshop` too?)
        - `8`: Null Sector
        - `9`: Venues not covered by `4`-`8`
- `2`: Now and Next
    - `21`-`23`: Stages A - C
    - `24`: Workshops
    - `25`: Null Sector
    - `26`: Other venues
    - `27`: All stages (maybe `20`?)
    - `29`: All venues - ordering should be as listed above? 
    - `2n...` has individual event entries with back routing, can be created statically by schedule generator
- `3`: Bar and Shop Prices
    - `31`: Bar (taps and pumps)
    - `32`: Bar (other)
    - `33`: Cybar
    - `34`: Shop
    - Sub-pages under each of these for categories/'departments'?
    - Include bar sessions somewhere?
- `4`: Guestbook
    - `41`: Sign
    - `42`: View
    - `49`: Terms/privacy policy
- `5`: Phone stuff
    - `51`: Telephone directory
    - `52`: Capture the phone game
    - `53`: Capture the phone leaderboard
    - `54`: Reminder call service
- `8`: About
    - `81`: About Viewdata
    - `82`: Telstar gateway
- `9`: Main index (Telstar's default is created here)
    - `90`: Logout page
    - `901`: System status
    - `99`: Welcome page
    - `990`: Full index

## Outstanding TODO items

As of 2024-05-15 01:30:

- Parameterise nav messages etc. for consistency
- General routing updates:
    - Decide on consistent scheme (maybe per section, but globally is better)
    - Update all navigation messages and routing tables
    - Do we have room for a second navigation line on event pages?
    - route final page of schedules back to something - start or index?
- Page `81`/`82` - About Viewdata/Telstar gateway - rewrite?  Service header?
- Page `83` - detail reminder call service
- Page `990` - full index
- Page `901` - add stats?
- cron jobs for automated updating
    - Schedule can be pulled hourly/*n* times a day/manually
    - Now/Next should update probably every 5 minutes if not every minute
- expose family-friendly flag
- handle huge fields in header block (e.g. 117051)
- Dockerise server with guestbook response handler etc.

## Things to check upstream

- Routing: any way to route to sub-frame?  Looks like no, but can work around this with numbered subpages instead (implemented 2022-03-04).
- Exit pages aren't displayed before disconnecting (fixed 2024-03-02)
- Disconnecting from gateway service doesn't return to local service
- History stack / back nav bug? (fixed 2024-03-02)

## Things to check in new schedule when available
- Sanitisation of `attendees` field (e.g. `(none)`, `Many` in 2022 dataset)
- Sanitisation of `cost` field (e.g. `£0`, `free` in 2022 dataset)