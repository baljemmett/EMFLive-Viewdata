-- Global kill switch for the mode menus - if disabled, everyone gets set to mode 1
hydration_support_modes = true;

-- Helper function to ask the user to confirm setting a hydration
hydration_confirm = function()
    app.Read("confirm", "reminder-call/prompts/set-confirm", 1, "s")
    return channel["confirm"]:get() == "1"
end;

-- Retrieve the current hydration subscription mode or 0 if not subscribed
hydration_mode = function(caller)
    local selected_mode = channel.HYDRATION_GetSubscriptionMode(caller):get()
    app.Verbose(1, "Current subscription mode for caller " .. caller .. " is " .. selected_mode)
    return tonumber(selected_mode)
end;

-- Check if the caller is currently subscribed to hydration reminders
hydration_enabled = function(caller)
    local enabled_count = channel.HYDRATION_IsNumberSubscribed(caller):get()
    return tonumber(enabled_count) > 0
end;

-- Helper function to check if a number is blocked from the service
-- For the time being, share the block list with the main reminder call service
hydration_is_blocked = function(caller)
    -- We can't return a call to an anonymous caller!
    if caller == "anonymous" then
        app.Verbose(1, "Anonymous caller, treating as blocked.")
        return true

    -- Caller ID of more than 6 digits has come from outside numbers;
    -- we can't place calls to the PSTN so these are de-facto blocked.
    elseif string.len(caller) > 6 then
        app.Verbose(1, "External call from " .. caller .. ", treating as blocked.")
        return true
    end

    local blocks = channel.REMINDERCALLS_IsPhoneNumberBlocked(caller):get()
    if blocks == nil or blocks == "" then blocks = "0" end

    if tonumber(blocks) > 0 then
        app.Verbose(1, "Call from " .. caller .. " blocked by request.")
        return true
    else
        return false
    end
end;

-- Confirmation flow for blocking the current caller from the service
hydration_handle_block_request = function(caller)
    app.Read("confirm", "reminder-call/prompts/confirm-block", 1, "s")
    if channel["confirm"]:get() == "1" then
        channel.REMINDERCALLS_BlockPhoneNumber(caller):get()

        if hydration_enabled(caller) then
            channel.HYDRATION_UnsubscribeNumber(caller):set("")
        end

        app.Playback("reminder-call/prompts/block-confirmed")
        app.Hangup()
    end
end;

-- Ask the user if they want to enable hydration reminders and do so if required
hydration_enable = function(caller)
    app.Read("confirm", "reminder-call/prompts/hydration-disabled", 1, "s")
    local response = channel["confirm"]:get()

    if response == "1" then
        -- Pressing 1 was a confirmation that they wish to subscribe...
        channel.HYDRATION_SubscribeNumber(caller, 1):set("")
        app.Playback("reminder-call/prompts/hydration-now-enabled")

    elseif response == "9" then
        -- Pressing 9 was a request to block the service on this number
        hydration_handle_block_request(caller)
    end
end;

-- Ask the user if they want to disable hydration reminders and do so if required
hydration_disable = function(caller)
    app.Read("confirm", "reminder-call/prompts/hydration-enabled", 1, "s")
    local response = channel["confirm"]:get()

    if response == "1" then
        -- Pressing 1 was a confirmation that they wish to subscribe...
        channel.HYDRATION_UnsubscribeNumber(caller):set("")
        app.Playback("reminder-call/prompts/hydration-now-disabled")

    elseif response == "9" then
        -- Pressing 9 was a request to block the service on this number
        hydration_handle_block_request(caller)
    end
end;

-- Read out the user's current subscription mode and allow them to change it
hydration_mode_menu = function(caller, current_mode)
    app.Read("confirm", "reminder-call/prompts/hydration-mode" .. tostring(current_mode), 1, "s")
    local response = channel["confirm"]:get()

    if response == "1" or response == "2" or response == "3" then
        -- Pressing 1 was a confirmation that they wish to subscribe...
        local mode = tonumber(response)
        channel.HYDRATION_SubscribeNumber(caller, mode):set("")
        app.Playback("reminder-call/prompts/hydration-now-mode" .. response)

    elseif response == "0" then
        -- Pressing 0 was a request to unsubscribe
        channel.HYDRATION_UnsubscribeNumber(caller):set("")
        app.Playback("reminder-call/prompts/hydration-now-disabled")

    elseif response == "9" then
        -- Pressing 9 was a request to block the service on this number
        hydration_handle_block_request(caller)
    end
end;


-- Handle the top-level hydration reminder call service prompts.
hydration_call_service = function(caller)
    if hydration_is_blocked(caller) then
        app.Playback("silence/1&reminder-call/prompts/blocked&silence/1")
        return
    end

    app.Playback("silence/1&reminder-call/prompts/hydration-welcome")

    if hydration_support_modes then
        local mode = hydration_mode(caller)
        hydration_mode_menu(caller, mode)
    elseif hydration_enabled(caller) then
        hydration_disable(caller)
    else
        hydration_enable(caller)
    end

    app.Playback("reminder-call/prompts/hydration-call-back")
end;

-- Wrapper to be called from the context/extension table entry.
hydration_extension = function(ctx, ext)
    caller = channel.CALLERID("num"):get()
    app.Verbose(1, "Call to reminder call service from " .. caller)
    app.Answer(250)
    hydration_call_service(caller)
    app.Hangup()
end;

-- Callback extension - to be invoked from a call file
hydration_callback = function(ctx, ext)
    hydration_id = channel.HydrationId:get()

    app.Playback("silence/1")

    if hydration_id == nil or hydration_id == "" then
        app.Verbose(1, "Hydration reminder callback attempted without valid hydration ID")
        app.Playback("reminder-call/prompts/internal-error-outgoing")
        app.Hangup()
        return
    end

    app.Verbose(1, "Hydration reminder callback for hydration ID " .. hydration_id)
    app.Playback("reminder-call/prompts/hydration-reminder")
    app.Playback("silence/1")
    app.Hangup()
end;
