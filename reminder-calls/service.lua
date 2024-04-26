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

    -- Need to do readback and confirmation prompt here...

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

-- Handle the top-level reminder call service prompts.
reminder_call_service = function(caller)
    app.Playback("silence/1&reminder-call/prompts/welcome")
    reminder_add(caller)
    app.Playback("reminder-call/prompts/finished")
end;

-- Wrapper to be called from the context/extension table entry.
reminder_extension = function(ctx, ext)
    caller = channel.CALLERID("num"):get()
    app.Answer()
    reminder_call_service(caller)
    app.Hangup()
end;
