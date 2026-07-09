-- Helper function to ask the user to confirm setting a hydration
hydration_confirm = function()
    app.Read("confirm", "reminder-call/prompts/set-confirm", 1, "s")
    return channel["confirm"]:get() == "1"
end;

hydration_enabled = function(caller)
    local enabled_count = channel.HYDRATION_IsNumberSubscribed(caller):get()
    return tonumber(enabled_count) > 0
end;

hydration_enable = function(caller)
    app.Read("confirm", "reminder-call/prompts/hydration-disabled", 1, "s")
    if channel["confirm"]:get() == "1" then
        channel.HYDRATION_SubscribeNumber(caller):set("")
        app.Playback("reminder-call/prompts/hydration-now-enabled")
    end
end;

hydration_disable = function(caller)
    app.Read("confirm", "reminder-call/prompts/hydration-enabled", 1, "s")
    if channel["confirm"]:get() == "1" then
        channel.HYDRATION_UnsubscribeNumber(caller):set("")
        app.Playback("reminder-call/prompts/hydration-now-disabled")
    end
end;

-- Handle the top-level hydration reminder call service prompts.
hydration_call_service = function(caller)
    app.Playback("silence/1&reminder-call/prompts/hydration-welcome")

    if hydration_enabled(caller) then
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
