-- Hook up the reminder call scripts to the dialplan
dofile("/opt/remindercalls/service.lua")
dofile("/opt/remindercalls/hydration-service.lua")

extensions = {
    emf_inbound = {
        ["remindercalls"] = reminder_extension;
        [2576] = reminder_extension;
        [49372] = hydration_extension;
    };

    emf_outbound = {
        ["remindercalls"] = reminder_callback;
        ["hydration"] = hydration_callback;
    };
}