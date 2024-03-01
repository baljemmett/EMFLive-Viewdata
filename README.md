# EMF Live Viewdata System

## Outstanding TODO items

As of 2024-03-01 14:24:

- Parameterise nav messages etc. for consistency
- Rearrange schedule pages to be individually numbered, not sub-frames?
    - e.g. `301a..301z` -> `301001..301026`, `3010a` -> `301027`
    - This allows schedule items to route back to the correct page instead of
    relying on working back through history with `*#` or having `0` take the
    user back to the first page of the schedule
- General routing updates:
    - Decide on consistent scheme (maybe per section, but globally is better)
    - Update all navigation messages and routing tables
    - Do we have room for a second navigation line on event pages?
- Which pages should Now/Next entries link to?
    - Currently they link to the full schedule, which means users get prev/next
    event nav and back-to-page-1-of-full-schedule nav options
    - Could link to venue schedule entry pages, which would give prev/next event
    nav per-venue but the 'index' route would be back to the venue schedule
    - Possibily link to new set of event pages just for Now/Next use; would allow
    'back' route to work more obviously, especially if Now/Next pages become
    individually numbered instead of using sub-frames
- Guestbook response handler and view
- Bar/shop stock pages - need to see more example data for this, ideally
- Scrub unused stock pages, customise those we're keeping
- How does 'index' nav work?  Check page number, move `*1#` if needed
- Check service header on all pages
- cron jobs for automated updating
    - Schedule can be pulled hourly/*n* times a day/manually
    - Now/Next should update probably every 5 minutes if not every minute

## Things to check upstream

- Routing: any way to route to sub-frame?  Looks like no, but can work around this
with numbered subpages instead.
- Exit pages aren't displayed before disconnecting
- Disconnecting from gateway service doesn't return to local service
- History stack / back nav bug?