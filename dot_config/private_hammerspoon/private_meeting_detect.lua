-- Hammerspoon script to automatically update your slack status when in a
-- Zoom or Google Meet meeting.
--
-- To use:
--
-- * Install and set up the slack_status.sh script (make sure it's in your
--   path)
-- * Ensure there is a 'zoom' preset (one is created by default during setup)
-- * Install hammerspoon (brew install hammerspoon) if you don't have it
--   already.
-- * Copy this file to ~/.config/hammerspoon
-- * Add the following line to ~/.config/hammerspoon/init.lua
--      local zoom_detect = require("zoom_detect")
-- * If it's a fresh `brew install` of Hammerspoon, start it and make sure
--   accessibility is enabled

-- Configuration
check_interval=20 -- How often to check if you're in a meeting, in seconds
meet_browsers = {"Zen"}
debug_log = false -- set true to print per-tick checks to Hammerspoon console

local function dbg(msg)
    if debug_log then hs.console.printStyledtext(msg) end
end

function update_status(status)
    -- Ensure there's a space between the script path and the status argument
    local command = hs.configdir .. "/slack_status.sh " .. status
    
    dbg("Updating Slack Status with command: " .. command)
    
    -- Execute the command and capture output and success status
    local output, success, _, _ = hs.execute(command, true)
    
    -- Check if the command was successful
    if success then
        dbg("Command executed successfully. Output: " .. output)
    else
        dbg("Command failed. Output: " .. output)
    end
end

function in_zoom_meeting()
    dbg("Checking for Zoom application...")
    -- Look up by bundle ID: Zoom 7.x spawns helper processes whose names
    -- also match "zoom.us" (e.g. "zoom.us Sidebar Web Content"), and
    -- find()/get() can return one of those; their menus read as nil.
    local zoomApp = hs.application.applicationsForBundleID("us.zoom.xos")[1]

    if zoomApp then
        dbg("Zoom application found. Retrieving all menu items...")
        local allMenuItems = getAllMenuItems(zoomApp)

        for _, title in ipairs(allMenuItems) do
            if title == "Meeting" then  -- Changed from "Join Meeting…" to "Meeting"
                dbg("'Meeting' menu item found. You are in a Zoom meeting.")
                return true
            end
        end

        dbg("'Meeting' menu item not found. You are not in a Zoom meeting.")
        return false
    else
        -- Zoom isn't running
        dbg("Zoom application not found.")
        return false
    end
end

function getAllMenuItems(app)
    local allTitles = {}

    local function gatherTitles(menuItems)
        for _, item in ipairs(menuItems) do
            if type(item) == "table" and item.AXTitle then
                table.insert(allTitles, item.AXTitle)
            end
            if item.AXChildren then
                gatherTitles(item.AXChildren[1])
            end
        end
    end

    local menuItems = app:getMenuItems()
    if menuItems then
        gatherTitles(menuItems)
    end

    return allTitles
end

function in_meet_meeting()
    -- Zen is Firefox-based: no AppleScript tab access, so match window titles
    -- instead. An active Meet call titles its tab "Meet - xxx-xxxx-xxx"; the
    -- landing page ("Google Meet") has no code and is excluded. Only detects
    -- the call while its tab is the window's active tab.
    -- hs.application.get() requires an exact name match of a *running* app,
    -- so it never fuzzy-matches other apps and never launches anything.
    for _, browser in ipairs(meet_browsers) do
        local app = hs.application.get(browser)
        if app then
            for _, w in ipairs(app:allWindows()) do
                local title = w:title() or ""
                if title:sub(1, 4) == "Meet" and title:match("%l+%-%l+%-%l+") then
                    dbg("Google Meet window found in " .. browser .. ": " .. title)
                    return true
                end
            end
        end
    end
    return false
end

in_meeting = false  -- false when idle, else preset name ("zoom" / "meet")
meetingTimer = hs.timer.doEvery(check_interval, function()
    local zoom = in_zoom_meeting()
    local meet = not zoom and in_meet_meeting()
    local preset = zoom and "zoom" or (meet and "meet" or nil)
    local kind = zoom and "Zoom" or (meet and "Google Meet" or nil)

    if preset then
        if in_meeting ~= preset then
            in_meeting = preset
            hs.notify.show("Started " .. kind .. " meeting", "Updating slack status", "")
            update_status(preset)
        end
    else
        if in_meeting then
            in_meeting = false
            hs.notify.show("Left meeting", "Updating slack status", "")
            update_status("none")
        end
    end
end)
meetingTimer:start()
