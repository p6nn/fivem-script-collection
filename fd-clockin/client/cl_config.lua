Config = Config or {}

Config.Locations = {
    ['Senora PD'] = {
        zones = {
            { 
			coords = vector3(2377.4404, 2626.8618, 46.7781),
			heading = 282.0, 
			minZ = 30.0, 
			maxZ = 60.0,
            debug = true,
            department = 'police' -- police or fire
			}
        }
    },
}

checkClocked = function()
    local state = LocalPlayer.state.clockedIn
    if state then
        if state.police then
            return "police"
        elseif state.fire then
            return "fire"
        end
    end
    return nil
end