function using(pkgn) file.Write( "\\using/json.lua", http.Get( "https://raw.githubusercontent.com/G-A-Development-Team/libs/main/json.lua" ) ) LoadScript("\\using/json.lua") local pkg = json.decode(http.Get("https://raw.githubusercontent.com/G-A-Development-Team/Using/main/using.json"))["pkgs"][ pkgn ] if pkg ~= nil then file.Write( "\\using/" .. pkgn .. ".lua", http.Get( pkg ) ) LoadScript("\\using/" .. pkgn .. ".lua") else print("[using] package doesn't exist. {" .. pkgn .. "}") end end

using "AdvancedEntitySystemReworkFFI" --By CarterPoe
using "Box"

local Libraries = {
    ["api_dev_11.6.2025_rev3"] = "https://raw.githubusercontent.com/G-A-Development-Team/CS2-AW-API-Extender/refs/heads/main/api.lua"
}

-- Script Loader Made By: Agentsix1 From G&A Development
----------------------
-- Don't Edit Below --
----------------------
local tbl = {}
for loc, url in pairs( Libraries ) do
    tbl[ loc ] = {}
    tbl[ loc ].found = false
    tbl[ loc ].url = url
end
Libraries = tbl

file.Enumerate( function( filename )
    
    for loc, data in pairs( Libraries ) do
        if filename == "libraries/" .. loc .. ".lua" then
            print( "[Library Loader] Library found " .. loc )
            Libraries[ loc ].found = true
        end
    end

end)

for loc, data in pairs( Libraries ) do
    if not Libraries[ loc ].found then
        local body = http.Get( data.url )
        file.Write("libraries/" .. loc .. ".lua", body)
        print( "[Library Loader] Getting new library " .. loc )
    end
end

for loc, data in pairs( Libraries ) do
    RunScript("libraries/" .. loc .. ".lua")
    print( "[Library Loader] Running " .. loc )
end


-- Robust local w2s that accepts Vector3 userdata or numeric tables
function w2s(vec)
    if not vec then return nil end
    local t = type(vec)

    -- If already a Vector3 (userdata), project directly
    if t == "userdata" then
        local ok, sx, sy = pcall(function()
            return client.WorldToScreen(vec)
        end)
        if ok and sx and sy then return sx, sy end
        return nil
    end

    -- If it's a table, coerce to Vector3 first
    if t == "table" then
        local x = vec.x ~= nil and vec.x or vec[1]
        local y = vec.y ~= nil and vec.y or vec[2]
        local z = vec.z ~= nil and vec.z or vec[3]
        if type(x) == "number" and type(y) == "number" and type(z) == "number" then
            local ok2, sx2, sy2 = pcall(function()
                return client.WorldToScreen(Vector3(tonumber(x), tonumber(y), tonumber(z)))
            end)
            if ok2 and sx2 and sy2 then return sx2, sy2 end
        end
    end

    return nil
end

-- Forward declare UI variables and font so functions can capture them
local box_color
local healthbar_cb
local box_pad
local keep_last_cb
local keep_last_time
local last_color
local show_name_cb
local name_size
local name_color
local ghost_name_color

-- simple cached font builder for names
local _name_font
local _name_font_size = -1
local function get_name_font(sz)
    sz = math.max(8, math.min(48, math.floor(tonumber(sz) or 14)))
    if not _name_font or _name_font_size ~= sz then
        _name_font = draw.CreateFont("Bahnschrift", sz, 600, true)
        _name_font_size = sz
    end
    return _name_font, sz
end

-- Local safe w2s that does not override global
local function w2s_safe(vec)
    if not vec then return nil end
    local ok, sx, sy = pcall(function() return client.WorldToScreen(vec) end)
    if ok and sx and sy then return sx, sy end
    if type(vec) == "table" then
        local x = vec.x ~= nil and vec.x or vec[1]
        local y = vec.y ~= nil and vec.y or vec[2]
        local z = vec.z ~= nil and vec.z or vec[3]
        if type(x) == "number" and type(y) == "number" and type(z) == "number" then
            local ok2, sx2, sy2 = pcall(function() return client.WorldToScreen(Vector3(x, y, z)) end)
            if ok2 and sx2 and sy2 then return sx2, sy2 end
        end
    end
    return nil
end

-- Override draw_box locally to ensure healthbar support even if external Box module lacks it
local function draw_box_override(ent, color, opts)
    if not ent or not ent.IsPlayer or not ent:IsPlayer() then return end

    -- head position
    local head
    do
        local okh, vhead = pcall(function() return ent:GetHitboxPosition(0) end)
        if okh and vhead then
            head = vhead
        else
            local okeye, veye = pcall(function()
                return (ent.GetPropVector and ent:GetPropVector("m_vecOrigin")) or (ent.GetOrigin and ent:GetOrigin())
            end)
            if okeye and veye then
                head = { x = veye.x, y = veye.y, z = veye.z + 72 }
            else
                return
            end
        end
    end

    -- feet position
    local feet
    do
        local okf, vfeet = pcall(function() return ent:GetAbsOrigin() end)
        if okf and vfeet then
            feet = vfeet
        else
            return
        end
    end

    local hx, hy = w2s(head)
    local fx, fy = w2s(feet)
    if not (hx and hy and fx and fy) then return end

    local height = math.abs(fy - hy)
    local width = height * 0.45
    local left = (fx - width * 0.5)
    local top = math.min(hy, fy)
    local right = left + width
    local bottom = math.max(hy, fy)

    -- apply padding to live box
    local pad_live = (box_pad and tonumber(box_pad:GetValue())) or 0
    top = top - pad_live
    bottom = bottom + pad_live

    local r = (color and color.r) or 255
    local g = (color and color.g) or 0
    local b = (color and color.b) or 0
    local a = (color and color.a) or 255

    draw.Color(r, g, b, a)
    draw.OutlinedRect(left, top, right, bottom)
    draw.Color(0, 0, 0, a)
    draw.OutlinedRect(left - 1, top - 1, right + 1, bottom + 1)

    -- name above box
    if show_name_cb and show_name_cb:GetValue() then
        local name = ""
        local okn, nm = pcall(function() return ent.GetName and ent:GetName() or "" end)
        if okn and type(nm) == "string" then name = nm end
        if name ~= "" then
            local font, sz = get_name_font(name_size and name_size:GetValue() or 14)
            draw.SetFont(font)
            local tw, th = draw.GetTextSize and draw.GetTextSize(name) or 0, sz
            local text_x = left + ((right - left) * 0.5) - (tw or 0) * 0.5
            local text_y = top - (th or sz) - 2 -- above box with small gap
            draw.Color(0, 0, 0, a)
            draw.Text(text_x + 1, text_y + 1, name)
            local nr, ng, nb, na = 255, 255, 255, 255
            if name_color and name_color.GetValue then
                nr, ng, nb, na = name_color:GetValue()
            end
            draw.Color(nr or 255, ng or 255, nb or 255, na or 255)
            draw.Text(text_x, text_y, name)
        end
    end

    -- health bar
    if opts and opts.healthbar then
        local hp = 0
        local okhp, val = pcall(function() return ent:GetHealth() end)
        if okhp and type(val) == "number" then hp = math.max(0, math.min(100, val)) end

        local bar_w = 3
        local bar_x1 = left - (bar_w + 3)
        local bar_x2 = bar_x1 + bar_w

        draw.Color(0, 0, 0, 160)
        draw.FilledRect(bar_x1 - 1, top - 1, bar_x2 + 1, bottom + 1)

        local h = bottom - top
        local filled_h = math.floor(h * (hp / 100))
        local fill_top = bottom - filled_h

        local rr, gg, bb = 0, 255, 0
        if hp <= 50 then
            local t = hp / 50
            rr = 255
            gg = math.floor(255 * t)
            bb = 0
        else
            local t = (hp - 50) / 50
            rr = math.floor(255 * (1 - t))
            gg = 255
            bb = 0
        end

        draw.Color(rr, gg, bb, 255)
        draw.FilledRect(bar_x1, fill_top, bar_x2, bottom)

        draw.Color(0, 0, 0, 200)
        draw.OutlinedRect(bar_x1 - 1, top - 1, bar_x2 + 1, bottom + 1)
    end
end

-- Replace global draw_box with our override so our script consistently shows the healthbar
-- Do not override global draw_box to avoid conflicts with other scripts
-- We'll call our local override directly where needed.

local tap = gui.Reference("Visuals", "Enemy")
local gbox1 = gui.Groupbox(tap, "SpottedESP", 383, 235, 350, 10);  -- gbox1
box_color = gui.ColorPicker(gbox1, "boxesp_color", "Box Color", 13, 255, 31, 255)
healthbar_cb = gui.Checkbox(gbox1, "spottedesp_healthbar", "Health bar (left)", true)
box_pad = gui.Slider(gbox1, "spottedesp_box_pad", "Box extra height (px)", 8, 0, 30)

-- Name settings
show_name_cb = gui.Checkbox(gbox1, "spottedesp_show_name", "Show name", true)
name_size = gui.Slider(gbox1, "spottedesp_name_size", "Name size", 14, 8, 48)
name_color = gui.ColorPicker(gbox1, "spottedesp_name_color", "Name color", 255, 255, 255, 255)
ghost_name_color = gui.ColorPicker(gbox1, "spottedesp_ghost_name_color", "Ghost name color", 220, 220, 220, 200)

-- New settings: persist last-spotted boxes
keep_last_cb = gui.Checkbox(gbox1, "spottedesp_keep_last", "Persist last-spotted box", true)
keep_last_time = gui.Slider(gbox1, "spottedesp_keep_last_time", "Persist Duration (s)", 6, 0, 15)
last_color = gui.ColorPicker(gbox1, "spottedesp_last_color", "Last-Spotted Color", 255, 220, 0, 255)

-- Storage for last known positions when enemies are spotted
local last_spotted = {}

local function safe_get_head(ent)
    local okh, vhead = pcall(function() return ent:GetHitboxPosition(0) end)
    if okh and vhead then return vhead end
    local okeye, veye = pcall(function()
        return (ent.GetPropVector and ent:GetPropVector("m_vecOrigin")) or (ent.GetOrigin and ent:GetOrigin())
    end)
    if okeye and veye then
        return { x = veye.x, y = veye.y, z = veye.z + 72 }
    end
    return nil
end

local function safe_get_feet(ent)
    local okf, vfeet = pcall(function() return ent:GetAbsOrigin() end)
    if okf and vfeet then return vfeet end
    return nil
end

local function draw_box_world(head, feet, color, opts)
    opts = opts or {}
    if not head or not feet then return end
    local hx, hy = w2s(head)
    local fx, fy = w2s(feet)
    if not (hx and hy and fx and fy) then return end

    local height = math.abs(fy - hy)
    local width = height * 0.45
    local left = (fx - width * 0.5)
    local top = math.min(hy, fy)
    local right = left + width
    local bottom = math.max(hy, fy)

    -- apply padding: push top up and bottom down by pad px
    local pad = tonumber(opts.pad ~= nil and opts.pad or (box_pad and box_pad:GetValue()) or 0) or 0
    top = top - pad
    bottom = bottom + pad

    local r = color.r or 255
    local g = color.g or 0
    local b = color.b or 0
    local a = color.a or 255

    draw.Color(r, g, b, a)
    draw.OutlinedRect(left, top, right, bottom)
    draw.Color(0, 0, 0, a)
    draw.OutlinedRect(left - 1, top - 1, right + 1, bottom + 1)

    -- Optional ghost name above box
    if show_name_cb and show_name_cb:GetValue() and type(opts.ghost_name) == "string" and opts.ghost_name ~= "" then
        local font, sz = get_name_font(name_size and name_size:GetValue() or 14)
        draw.SetFont(font)
        local tw, th = draw.GetTextSize and draw.GetTextSize(opts.ghost_name) or 0, sz
        local text_x = left + ((right - left) * 0.5) - (tw or 0) * 0.5
        local text_y = top - (th or sz) - 2
        draw.Color(0, 0, 0, a)
        draw.Text(text_x + 1, text_y + 1, opts.ghost_name)
        local gr, gg, gb, ga = 220, 220, 220, 200
        if ghost_name_color and ghost_name_color.GetValue then
            gr, gg, gb, ga = ghost_name_color:GetValue()
        end
        draw.Color(gr or 220, gg or 220, gb or 220, ga or 200)
        draw.Text(text_x, text_y, opts.ghost_name)
    end

    -- Optional ghost health bar
    if opts.healthbar and type(opts.ghost_hp) == "number" then
        local hp = math.max(0, math.min(100, math.floor(opts.ghost_hp)))
        local bar_w = 3
        local bar_x1 = left - (bar_w + 3)
        local bar_x2 = bar_x1 + bar_w

        draw.Color(0, 0, 0, 160)
        draw.FilledRect(bar_x1 - 1, top - 1, bar_x2 + 1, bottom + 1)

        local h = bottom - top
        local filled_h = math.floor(h * (hp / 100))
        local fill_top = bottom - filled_h

        local rr, gg, bb = 0, 255, 0
        if hp <= 50 then
            local t = hp / 50
            rr = 255
            gg = math.floor(255 * t)
            bb = 0
        else
            local t = (hp - 50) / 50
            rr = math.floor(255 * (1 - t))
            gg = 255
            bb = 0
        end

        draw.Color(rr, gg, bb, 255)
        draw.FilledRect(bar_x1, fill_top, bar_x2, bottom)

        draw.Color(0, 0, 0, 200)
        draw.OutlinedRect(bar_x1 - 1, top - 1, bar_x2 + 1, bottom + 1)
    end
end

local function get_player_by_index( index )
    local players = Players()
    for _, ply in pairs( players ) do
        if ply:GetIndex() == index then return ply end
    end
end

callbacks.Register("Draw", "SpottedESP", function()
    local localEnt = LocalPlayer()
    if not localEnt then return end
    local localIndex = localEnt:GetIndex()
    local localTeam = localEnt:GetTeamNumber()

    local controllers = GetPlayerControllers()
    if #controllers == 0 then return end

    local now = common.Time and common.Time() or globals.FrameTime() or 0

    -- Track which ghosts we already drew via controller loop
    local drew_ghost = {}

    for _, controller in pairs(controllers) do
        -- Skip bad controllers
        if controller and controller.GetFieldInt then
            -- Resolve pawn handle to pawn and check spotted state
            local pawnHandle = controller:GetFieldInt("m_hPawn")
            if pawnHandle and pawnHandle ~= 0 then
                local pawn = entitiesV2.GetPlayerPawnFromHandle(pawnHandle)
                if pawn then
                    local spottedTable = pawn:GetFieldTable("m_entitySpottedState")
                    local is_spotted = false
                    if type(spottedTable) == "table" then
                        is_spotted = (spottedTable.m_bSpotted == true) or (spottedTable.m_bSpotted == 1)
                    end
    
                    -- Convert handle -> entity index -> game entity for drawing
                    local pawnIndex = bit.band(pawnHandle, 0x7FFF)
                    local ent = entities.GetByIndex(pawnIndex)
    
                    if is_spotted then
                        if ent and ent:IsPlayer() and ent:IsAlive() then
                            local entTeam = ent:GetTeamNumber()
                            if ent:GetIndex() ~= localIndex and entTeam ~= localTeam then
                                local r1, g1, b1, a1 = box_color:GetValue()
                                draw_box_override(ent, { r = r1, g = g1, b = b1, a = a1 }, { healthbar = healthbar_cb:GetValue() })
                                -- Mark as currently spotted so ghost is not drawn this frame
                                drew_ghost[pawnIndex] = true
    
                                -- update last known position/time if enabled
                                if keep_last_cb:GetValue() then
                                    local head = safe_get_head(ent)
                                    local feet = safe_get_feet(ent)
                                    if head and feet then
                                        local hp = 0
                                        local okhp, valhp = pcall(function() return ent:GetHealth() end)
                                        if okhp and type(valhp) == "number" then hp = math.max(0, math.min(100, valhp)) end
                                        local pname = ""
                                        local okpn, nm = pcall(function() return ent.GetName and ent:GetName() or "" end)
                                        if okpn and type(nm) == "string" then pname = nm end
                                        last_spotted[pawnIndex] = { head = { x = head.x, y = head.y, z = head.z }, feet = { x = feet.x, y = feet.y, z = feet.z }, hp = hp, name = pname, t = now }
                                    end
                                end
                            end
                        end
                    else
                        -- Not currently spotted: draw ghost if still within duration
                        if keep_last_cb:GetValue() and last_spotted[pawnIndex] then
                            local data = last_spotted[pawnIndex]
                            local dur = keep_last_time:GetValue()
                            if dur > 0 and now - (data.t or 0) <= dur then
                                local lr, lg, lb, la = last_color:GetValue()
                                -- draw exactly like spotted box, but with ghost settings
                                draw_box_world(data.head, data.feet, { r = lr, g = lg, b = lb, a = la }, {
                                    pad = box_pad and box_pad:GetValue() or 0,
                                    healthbar = healthbar_cb and healthbar_cb:GetValue() or false,
                                    ghost_hp = data.hp,
                                    ghost_name = data.name
                                })
                                drew_ghost[pawnIndex] = true
                            else
                                -- expire
                                last_spotted[pawnIndex] = nil
                            end
                        end
                    end
                end
            end
        end -- end controller guard
    end

    -- Also draw any remaining ghosts for which we didn't see a controller entity this frame
    if keep_last_cb and keep_last_cb:GetValue() then
        local dur = (keep_last_time and keep_last_time:GetValue()) or 0
        if dur > 0 then
            for idx, data in pairs(last_spotted) do
                local ply = get_player_by_index( idx )
                if not ply or not ply:IsAlive() then
                     last_spotted[idx] = nil
                end
                if not drew_ghost[idx] and (now - (data.t or 0) <= dur) then
                    local lr, lg, lb, la = last_color:GetValue()
                    draw_box_world(data.head, data.feet, { r = lr, g = lg, b = lb, a = la }, {
                        pad = box_pad and box_pad:GetValue() or 0,
                        healthbar = healthbar_cb and healthbar_cb:GetValue() or false,
                        ghost_hp = data.hp,
                        ghost_name = data.name
                    })
                elseif now - (data.t or 0) > dur then
                    last_spotted[idx] = nil
                end
            end
        end
    end
end)

print( "SpottedESP - v1.1 - Made By: Carter Poe & Agentsix1 (11.18.2025)" )
