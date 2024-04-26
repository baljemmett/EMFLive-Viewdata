-- Venue information, in case we want to use it in announcements at some point.
--      venue_id     - internal ID value used just as a key
--      venue_name   - venue name string as it appears in the schedule
--      venue_phrase - filename of sound clip containing preposition and name
create table venues (
    venue_id integer primary key generated always as identity,
    venue_name text not null,
    venue_phrase text not null
);

create index venue_name on venues(venue_name);

-- Event information, because this is basically the whole point of the thing.
--      event_id        - taken from the schedule
--      venue_id
--      start_time
--      end_time
--      title           - taken from the schedule, just for reference
--      remindercode    - as generated and shown in the Viewdata schedule
--      title_phrase    - filename of sound clip containing just the title
--      reminder_prhase - filename of sound clip containing full event billing
create table events (
    event_id integer primary key,
    venue_id integer references venues(venue_id) not null,
    start_time timestamp with time zone not null,
    end_time timestamp with time zone not null,
    title text not null,
    remindercode text not null,
    title_phrase text not null,
    reminder_phrase text not null
);

create index events_start_time on events(start_time);
create index events_end_time on events(end_time);
create index events_remindercode on events(remindercode);

-- List of reminders that have been requested by users.
--      reminder_id
--      reminder_time - time at which the reminder needs to be delivered
--      event_id      - NULL for timed reminder calls, or ID of selected event
--      phone_number  - number to call the user back on at reminder time
--      status        - pending/despatched/delivered/failed/cancelled
--      created       - when the user added this reminder call
--      updated       - time of last status change
create table reminders (
    reminder_id integer primary key generated always as identity,
    reminder_time timestamp with time zone not null,
    event_id integer references events(event_id),
    phone_number text not null,
    status text not null,
    created timestamp with time zone not null,
    updated timestamp with time zone not null
);

create index reminders_time_status on reminders(reminder_time, status);
create index reminders_phone_status on reminders(phone_number, status);

-- A basic log of changes to all reminder requests, for debugging etc.
--      history_id
--      reminder_id
--      updated     - time this change was made
--      log_entry   - description of the change
create table history (
    history_id integer primary key generated always as identity,
    reminder_id integer references reminders(reminder_id) not null,
    updated timestamp with time zone not null,
    log_entry text not null
);

create index history_reminder on history(reminder_id);
