local splash = true
local splashwait = 5

local card = [[
{
  "type": "AdaptiveCard",
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "version": "1.3",
  "body": [
    {
      "type": "Image",
      "url": "",
      "horizontalAlignment": "Center"
    },
    {
      "type": "Container",
      "items": [
        {
          "type": "TextBlock",
          "text": "Straya Skids Freeroam",
          "wrap": true,
          "fontType": "Default",
          "size": "ExtraLarge",
          "weight": "Bolder",
          "color": "Light",
          "horizontalAlignment": "Center"
        },
        {
          "type": "TextBlock",
          "text": "You do not have the 'Freeroam' role in the Discord.",
          "wrap": true,
          "color": "Light",
          "size": "Medium",
          "horizontalAlignment": "Center"
        },
        {
          "type": "ColumnSet",
          "height": "stretch",
          "minHeight": "100px",
          "bleed": true,
          "horizontalAlignment": "Center",
          "columns": [
            {
              "type": "Column",
              "width": "stretch",
              "items": [
                {
                  "type": "ActionSet",
                  "actions": [
                    {
                      "type": "Action.OpenUrl",
                      "title": "Join Discord",
                      "url": "https://discord.gg/strayaskids"
                    },
                    {
                      "type": "Action.Submit",
                      "title": "I have the role",
                      "id": "check_role",
                      "style": "positive"
                    }
                  ],
                  "horizontalAlignment": "Center"
                }
              ],
              "height": "stretch",
              "horizontalAlignment": "Center",
              "verticalContentAlignment": "Center"
            }
          ]
        }
      ],
      "style": "default",
      "bleed": true,
      "height": "stretch"
    }
  ]
}
]]

if splash then
    AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
        deferrals.defer()
        local src = source

        if hasRole(src, "Freeroam") then
            dbg('^2[Deferral]^7 Player has role: ' .. name)
            Wait(1000)
            deferrals.done()
            dbg('^2[Deferral]^7 Done - Player ' .. name .. ' is now joining server.')
            return
        end

        dbg("^1[Deferral]^7 Player missing 'Freeroam' role: " .. name)

        local function showCard()
            deferrals.presentCard(card, function(data)
                dbg("^3[Deferral]^7 Player clicked retry. Rechecking...")
                ReloadPlayerRoles(src)

                Wait(1000)

                if hasRole(src, "Freeroam") then
                    dbg("^2[Deferral]^7 Player now has 'Freeroam' role. Letting them in.")
                    Wait(1000)
                    deferrals.done()
                    dbg("^2[Deferral]^7 Done - Player " .. name .. " is now joining server.")
                else
                    dbg("^1[Deferral]^7 Player still missing role. Showing card again...")
                    showCard()
                end
            end)
        end

        showCard()
    end)
end
