function using(pkgn) file.Write( "\\using/json.lua", http.Get( "https://raw.githubusercontent.com/G-A-Development-Team/libs/main/json.lua" ) ) LoadScript("\\using/json.lua") local pkg = json.decode(http.Get("https://raw.githubusercontent.com/G-A-Development-Team/Using/main/using.json"))["pkgs"][ pkgn ] if pkg ~= nil then file.Write( "\\using/" .. pkgn .. ".lua", http.Get( pkg ) ) LoadScript("\\using/" .. pkgn .. ".lua") else print("[using] package doesn't exist. {" .. pkgn .. "}") end end

using "AdvancedEntitySystemReworkFFI" --By CarterPoe
using "W2S"
using "Box"

local tap = gui.Reference("Visuals", "Enemy")
local gbox1 = gui.Groupbox(tap, "SpottedESP", 383, 253, 350, 0);  -- gbox1
local box_color = gui.ColorPicker(gbox1, "boxesp_color", "Box Color", 13, 255, 31, 255)

callbacks.Register("Draw", "SpottedESP", function()
   local localEnt = entities.GetLocalPlayer()
   if not localEnt then return end
   local localIndex = localEnt:GetIndex()
   local localTeam = localEnt:GetTeamNumber()

   local controllers = entities.FindByClass("CCSPlayerController")
   if #controllers == 0 then return end

   for _, controller in pairs(controllers) do
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
               if is_spotted then
                   -- Convert handle -> entity index -> game entity for drawing
                   local pawnIndex = bit.band(pawnHandle, 0x7FFF)
                   local ent = entities.GetByIndex(pawnIndex)
                   if ent and ent:IsPlayer() and ent:IsAlive() then
                       local entTeam = ent:GetTeamNumber()
                       if ent:GetIndex() ~= localIndex and entTeam ~= localTeam then
                        local r1, g1, b1, a1 = box_color:GetValue()
                           draw_box(ent, { r = r1, g = g1, b = b1, a = a1 })
                       end
                   end
               end
           end
       end
   end
end)

print( "SpottedESP - v1.0 - Made By: Carter Poe & Agentsix1 (11.16.2025)" )
