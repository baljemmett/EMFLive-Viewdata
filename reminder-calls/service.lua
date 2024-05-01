-- Helper function to ask the user to confirm setting a reminder
reminder_confirm = function()
    app.Read("confirm", "reminder-call/prompts/set-confirm", 1, "s")
    return channel["confirm"]:get() == "1"
end;

-- Handle the add-reminder-by-time flow for a caller and their requested time.
reminder_add_time = function(caller, time)
    -- Parse the four-digit time into hours and minutes, as strings and ints
    local hours_str = string.sub(time, 1, 2)
    local minutes_str = string.sub(time, 3, 4)
    local hours = tonumber(hours_str, 10)
    local minutes = tonumber(minutes_str, 10)

    -- Check they parsed to ints properly and are within bounds
    if hours == nil or minutes == nil or hours >= 24 or minutes >= 60 then
        app.Playback("reminder-call/prompts/bad-time")
        return false
    end

    -- Turn hh:mm into a proper timestamp, starting from today's date
    local now_time = os.time()              -- get right now as time_t
    local now = os.date("*t", now_time)     -- format into table
    local reminder = now                    -- take a copy of it

    reminder.hour = hours                   -- set time in copy
    reminder.min  = minutes
    reminder.sec  = 0

    local reminder_time = os.time(reminder) -- convert copy back to time_t
    local is_today = true

    if (reminder_time <= now_time) then     -- has time already passed?
        is_today = false                    -- if so, make it tomorrow
        reminder_time = reminder_time + 24 * 60 * 60
    end

    -- Finally we can convert the requested time into a full timestamp string
    local reminder_timestamp = os.date("%Y-%m-%d %H:%M:%S", reminder_time)

    -- Read it back to the user, with today/tomorrow suffix for clarity;
    -- special-case midnight, as well as 0001-0059 and the tops of hours.
    app.Playback("reminder-call/prompts/set-for-time")

    if time == "0000" then
        app.Playback("reminder-call/times/midnight")
    else
        if hours == 0 then
            app.Playback("reminder-call/times/double-oh")
        else
            app.Playback("reminder-call/numbers/" .. hours_str)
        end

        if minutes == 0 then
            app.Playback("reminder-call/times/hundred")
        else
            app.Playback("reminder-call/numbers/" .. minutes_str)
        end

        if is_today then
            app.Playback("reminder-call/days/tod")
        else
            app.Playback("reminder-call/days/tom")
        end
    end

    -- Confirm they want to go ahead with this time
    if not reminder_confirm() then return false end

    -- Schedule the reminder call!
    local reminder_id = channel.REMINDERCALLS_ScheduleForTime(caller, reminder_timestamp):get()
    if reminder_id == nil or reminder_id == "" then
        -- Failed, which is probably very bad news; bail out!
        app.Verbose(1, "Reminder creation for caller " .. caller .. ", time " .. time .. " failed!")
        app.Playback("reminder-call/prompts/internal-error")
        app.Hangup()
        return false
    end

    app.Verbose(1, "Reminder creation for caller " .. caller .. ", time " .. time .. " produced ID " .. reminder_id)

    -- Create initial history log entry
    local log = "Requested by caller " .. caller .. " for time " .. time;
    channel.REMINDERCALLS_AddHistoryEntry(reminder_id):set(log)

    return true;
end;

-- Handle the add-reminder-by-code flow for a caller and their requested event.
reminder_add_code = function(caller, code)
    -- First, look up the reminder code to get the event ID (if code's valid!)
    local event_id = channel.REMINDERCALLS_EventIdFromReminderCode(code):get()

    if event_id == nil or event_id == "" then
        app.Verbose(1, "Event lookup for code " .. code .. " failed; invalid?")
        app.Playback("reminder-call/prompts/bad-code")
        return false
    else
        app.Verbose(1, "Event lookup for code " .. code .. " found ID " .. event_id)
    end

    -- Now we can look for the title clip filename
    local title = channel.REMINDERCALLS_EventTitleFilenameFromId(event_id):get()

    if title == nil or title == "" then
        app.Verbose(1, "Title filename lookup for event " .. event_id .. " failed; invalid?")
        app.Playback("reminder-call/prompts/bad-code")
        return false
    else
        app.Verbose(1, "Title filename lookup for event " .. event_id .. " found " .. title)
    end

    -- Read it out to the user and check if it's right
    app.Playback("reminder-call/prompts/set-for-event")
    app.Playback("reminder-call/" .. title)
    if not reminder_confirm() then return false end

    -- Schedule the reminder call; time is computed up automatically
    local reminder_id = channel.REMINDERCALLS_ScheduleForEvent(caller, event_id):get()

    if reminder_id == nil or reminder_id == "" then
        -- Failed, which is probably still very bad news; bail out!
        app.Verbose(1, "Reminder creation for caller " .. caller .. ", event " .. event_id .. " failed!")
        app.Playback("reminder-call/prompts/internal-error")
        app.Hangup()
        return false
    end

    app.Verbose(1, "Reminder creation for caller " .. caller .. ", event " .. event_id .. " produced ID " .. reminder_id)

    -- Create initial history log entry
    local log = "Requested by caller " .. caller .. " with reminder code " .. code;
    channel.REMINDERCALLS_AddHistoryEntry(reminder_id):set(log)

    return true;
end;

-- Handle the main 'add new reminder' flow and sub-branches
reminder_add = function(caller)
    -- Put a cap on attempts in case we forget to double-check the channel's
    -- active when we Read() from it - learned that the hard way...
    local max_tries = 10

    while max_tries > 0 do
        max_tries = max_tries - 1

        -- Ask the user for the time (or * then code), bailing out on *
        app.Read("time", "reminder-call/prompts/enter-time", 4, "st(*)")

        local status = channel["READSTATUS"]:get()
        local time = channel["time"]:get()

        -- If the Read() aborted due to failure, give up immediately
        if status == "ERROR" or status == "HANGUP" then
            return

        -- An empty time string means the user dialled * first...
        elseif time == "" then
            -- ... so read the reminder code instead of a time
            app.Read("code", "", 6, "s")
            local code = channel["code"]:get()
            app.Verbose(1, "User entered code " .. code)

            -- If the 'add by code' flow succeeds, we're done.
            if reminder_add_code(caller, code) then return end

        -- A four-digit number is potentially a valid time, so
        -- try the 'add by time' flow; if it succeeds, we're done
        elseif string.match(time, "%d%d%d%d") then
            app.Verbose(1, "User entered time " .. time)
            if reminder_add_time(caller, time) then return end

        -- Anything else happening here is probably nonsense input
        else
            app.Verbose(1, "Invalid user input")
            app.Playback("reminder-call/prompts/not-recognised")
        end

        app.Verbose(1, "Trying again due to bad or cancelled input")
    end
end;

-- Read out the details of a specified reminder
reminder_review_one = function(caller, number, reminder_id)
    local time = channel.REMINDERCALLS_ReminderTimeFromId(reminder_id):get()
    local event = channel.REMINDERCALLS_EventIdFromReminderId(reminder_id):get()

    -- This is really a bit grotty but if we try to return multiple columns
    -- from the SELECT query, Asterisk gives us a comma-separated list...
    local day = string.sub(time, 1, 3)
    local hours = string.sub(time, 5, 6)
    local minutes = string.sub(time, 8, 9)

    -- Spit out the details for debugging
    app.Verbose(1, "Reminder " .. number .. " for caller " .. caller .. ", id " .. reminder_id .. ":")
    app.Verbose(1, day)
    app.Verbose(1, hours)
    app.Verbose(1, minutes)

    -- Read out which number this is in the list (before any cancellations)
    app.Playback("reminder-call/prompts/reminder-number")
    if number < 10 then
        app.Playback("reminder-call/digits/" .. number)
    else
        app.Playback("reminder-call/numbers/" .. number)
    end

    --- ... and the day and time
    app.Playback("reminder-call/days/" .. day)

    if hours == 0 and minutes == 0 then
        app.Playback("reminder-call/times/midnight")
    else
        if hours == 0 then
            app.Playback("reminder-call/times/double-oh")
        else
            app.Playback("reminder-call/numbers/" .. hours)
        end

        if minutes == 0 then
            app.Playback("reminder-call/times/hundred")
        else
            app.Playback("reminder-call/numbers/" .. minutes)
        end
    end

    -- Does it have an associated event to read out?
    if event ~= nil and event ~= "" then
        local title = channel.REMINDERCALLS_EventTitleFilenameFromId(event):get()

        if title ~= nil and title ~= "" then
            app.Playback("reminder-call/prompts/reminder-event")
            app.Playback("reminder-call/" .. title)
        end
    end
end;

-- Review all reminder set for a user, offering the option to delete each one
reminder_review_all = function(caller)
    local query_id = channel.REMINDERCALLS_GetPendingReminderIdsForUser(caller):get()
    local reminder_id = channel.ODBC_FETCH(query_id):get()
    local number = 1

    -- Keep going until we run out of rows *or* we hit the sixtieth reminder,
    -- because we only have the numbers 0..59 in our vocabulary.
    while number < 60 and channel["ODBC_FETCH_STATUS"]:get() == "SUCCESS" do
        -- Read this reminder out to the user
        reminder_review_one(caller, number, reminder_id)

        -- Give them the prompt to cancel it
        app.Read("menu", "reminder-call/prompts/review-prompt", 1, "st(5)")
        if channel["menu"]:get() == "2" then
            app.Verbose("... cancelling reminder " .. reminder_id)
            channel.REMINDERCALLS_CancelReminderById(reminder_id):set("")

            local log = "Cancelled by caller (" .. caller .. ")."
            channel.REMINDERCALLS_AddHistoryEntry(reminder_id):set(log)

            app.Playback("reminder-call/prompts/cancelled")
        end
    
        -- Move on to the next reminder
        reminder_id = channel.ODBC_FETCH(query_id):get()
        number = number + 1
    end

    channel.ODBCFinish(query_id)
    return false
end;

-- Cancel all outstanding reminders for a user, after confirmation
reminder_cancel_all = function(caller)
    -- Give the user a chance to bail out if this was a mistake
    app.Read("confirm", "reminder-call/prompts/cancel-all", 1, "s")
    if channel["confirm"]:get() ~= "3" then return false end

    app.Verbose("Caller " .. caller .. " cancelling all reminders")

    -- We cancel the reminders one-by-one so that we can create the correct
    -- set of history records, but we'll cap it at 100 rows so the script
    -- doesn't spin indefinitely if I mess up the ODBC fetching...
    local max_iterations = 100

    -- Get the first pending reminder for the user
    local query_id = channel.REMINDERCALLS_GetPendingReminderIdsForUser(caller):get()
    local reminder_id = channel.ODBC_FETCH(query_id):get()

    while max_iterations > 0 and channel["ODBC_FETCH_STATUS"]:get() == "SUCCESS" do
        -- Cancel this reminder...
        app.Verbose("... cancelling reminder " .. reminder_id)
        channel.REMINDERCALLS_CancelReminderById(reminder_id):set("")

        -- ... log what we did...
        local log = "Cancelled by caller (" .. caller .. ") as part a cancel-all request."
        channel.REMINDERCALLS_AddHistoryEntry(reminder_id):set(log)

        -- ... and look for another one
        reminder_id = channel.ODBC_FETCH(query_id):get()
        max_iterations = max_iterations - 1
    end

    channel.ODBCFinish(query_id)
    
    app.Playback("reminder-call/prompts/cancelled-all")
    return true
end;

-- Get (and read out) the number of reminder calls currently pending for a user
reminder_call_pending_count = function(caller)
    local pending = channel.REMINDERCALLS_GetPendingReminderCountForUser(caller):get()

    if pending == nil or pending == "" then pending = "0" end
    pending = tonumber(pending)

    if pending == 1 then
        app.Playback("reminder-call/prompts/you-have-one-reminder-set")
    elseif pending > 30 then
        app.Playback("reminder-call/prompts/you-have-many-reminders-set")
    elseif pending > 0 then
        app.Playback("reminder-call/prompts/you-have")

        if pending < 10 then
            app.Playback("reminder-call/digits/" .. pending)
        else
            app.Playback("reminder-call/numbers/" .. pending)
        end

        app.Playback("reminder-call/prompts/reminders-set")
    end

    return pending
end;

-- Main menu to handle callers who already have reminders set.
-- Returns true when done, or false if we need to loop back here.
reminder_call_menu = function(caller)
    app.Read("menu", "reminder-call/prompts/main-menu", 1, "s")

    local status = channel["READSTATUS"]:get()
    local menu = channel["menu"]:get()

    -- If the Read() aborted due to failure, give up immediately
    if status == "ERROR" or status == "HANGUP" then
        return true
    elseif menu == "1" then
        reminder_add(caller)
        return true
    elseif menu == "2" then
        return reminder_review_all(caller)
    elseif menu == "3" then
        return reminder_cancel_all(caller)
    else
        app.Playback("reminder-call/prompts/not-recognised")
        return false
    end
end;

-- Handle the top-level reminder call service prompts.
reminder_call_service = function(caller)
    app.Playback("silence/1&reminder-call/prompts/welcome")

    if reminder_call_pending_count(caller) == 0 then
        reminder_add(caller)
    else
        while not reminder_call_menu(caller) do
            reminder_call_pending_count(caller)
        end
    end

    app.Playback("reminder-call/prompts/finished")
end;

-- Wrapper to be called from the context/extension table entry.
reminder_extension = function(ctx, ext)
    caller = channel.CALLERID("num"):get()
    app.Answer()
    reminder_call_service(caller)
    app.Hangup()
end;

-- Callback extension - to be invoked from a call file
reminder_callback = function(ctx, ext)
    reminder_id = channel.ReminderId:get()

    app.Playback("silence/1")

    if reminder_id == nil or reminder_id == "" then
        app.Verbose(1, "Callback attempted without valid reminder ID")
        app.Playback("reminder-call/prompts/internal-error-outgoing")
        app.Hangup()
        return
    end

    app.Verbose(1, "Reminder callback for reminder ID " .. reminder_id)

    local time = channel.REMINDERCALLS_ReminderTimeFromId(reminder_id):get()
    local event = channel.REMINDERCALLS_EventIdFromReminderId(reminder_id):get()

    if event ~= nil and event ~= "" then
        -- This is a reminder for an event, so find the announcement
        -- filename and play it out
        local title = channel.REMINDERCALLS_EventReminderFilenameFromId(event):get()

        if title ~= nil and title ~= "" then
            app.Playback("reminder-call/" .. title)
        end
    elseif time ~= nil and time ~= "" then
        -- This is a reminder for a time, so announce that and the
        -- time it was requested for.
        app.Playback("reminder-call/prompts/time-message")

        -- This is really a bit grotty but if we try to return multiple columns
        -- from the SELECT query, Asterisk gives us a comma-separated list...
        local hours = string.sub(time, 5, 6)
        local minutes = string.sub(time, 8, 9)

        if hours == 0 and minutes == 0 then
            app.Playback("reminder-call/times/midnight")
        else
            if hours == 0 then
                app.Playback("reminder-call/times/double-oh")
            else
                app.Playback("reminder-call/numbers/" .. hours)
            end

            if minutes == 0 then
                app.Playback("reminder-call/times/hundred")
            else
                app.Playback("reminder-call/numbers/" .. minutes)
            end
        end
    else
        -- Couldn't find any details about the reminder ID?!
        app.Verbose(1, "Callback attempted but reminder ID lookup failed")
        app.Playback("reminder-call/prompts/internal-error-outgoing")
        app.Hangup()
        return
    end

    app.Playback("reminder-call/prompts/finished")
    app.Playback("silence/1")
    app.Hangup()
end;
