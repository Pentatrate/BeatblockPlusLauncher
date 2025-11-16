local st = Gamestate:new("Launcher")

function st.moveDirectory(source, target)
    love.filesystem.createDirectory(target)

    local files = love.filesystem.getDirectoryItems(source)
    for _, file in pairs(files) do
        local sourceFilePath = source .. file
        local targetFilePath = target .. file

        local contents = love.filesystem.read(sourceFilePath)
        if contents then
            local targetFile = love.filesystem.newFile(targetFilePath)
            targetFile:open("w")
            targetFile:write(contents)
            targetFile:flush()
            love.filesystem.remove(sourceFilePath)
        end
    end

    love.filesystem.remove(source)
end

function st:reloadModList()
	self.modList = {}
	for _, v in pairs(mods) do if st.checkValid(v.id) then table.insert(self.modList, v) end end
	table.sort(self.modList, function(a, b)
		if self.getModEnabled(a) ~= self.getModEnabled(b) then
			return self.getModEnabled(a)
		elseif a.name:lower() ~= b.name:lower() then
			return a.name:lower() < b.name:lower()
		elseif a.author:lower() ~= b.author:lower() then
			return a.author:lower() < b.author:lower()
		else
			return a.id < b.id
		end
	end)
end

function st.checkValid(name)
	return not ({ ["beatblock-plus"] = true, ["beatblock-plus-launcher"] = true })[name]
end

function st.getModEnabled(mod)
	return mods["beatblock-plus-launcher"].config.profiles[mods["beatblock-plus-launcher"].config.currentProfile][mod.id]
end

st:setInit(function(self)
	self.initing = true
	self.size = 1
	self.command = ""
	mods["beatblock-plus-launcher"].config.currentProfile = mods["beatblock-plus-launcher"].config.currentProfile or "Enable All"

	self.modList = {}
	for _, v in pairs(mods) do if st.checkValid(v.id) then table.insert(self.modList, v) end end

	mods["beatblock-plus-launcher"].config.profiles = mods["beatblock-plus-launcher"].config.profiles or {}
	if mods["beatblock-plus-launcher"].config.profiles["Enable All"] == nil then
		mods["beatblock-plus-launcher"].config.profiles["Enable All"] = {}
	end
	for i, mod in ipairs(self.modList) do
		for k, v in pairs(mods["beatblock-plus-launcher"].config.profiles) do
			if v[mod.id] == nil then v[mod.id] = k == "Enable All" and true or mod.enabled end
		end
	end

	table.sort(self.modList, function(a, b)
		if a.enabled ~= b.enabled then
			return a.enabled
		elseif a.name:lower() ~= b.name:lower() then
			return a.name:lower() < b.name:lower()
		elseif a.author:lower() ~= b.author:lower() then
			return a.author:lower() < b.author:lower()
		else
			return a.version < b.version
		end
	end)
end)

st:setUpdate(function(self, dt)
	if self.doRelaunch then
		local lastLaunchArgs = helpers.copy(arg)
		local lauchArgsString = table.concat(arg, " ")
		local restartGame = false -- restart the game fully
		local launchVanilla = false -- dont enable/disable mods

		for k, _ in pairs({ ["--launch"] = true, ["--disable-mods"] = true, ["--disable-console"] = true }) do
			if self.doRelaunch[k] then
				if k == "--disable-mods" then launchVanilla = true restartGame = true end
				if not lauchArgsString:find(k) then
					if k ~= "--launch" then restartGame = true end
					table.insert(lastLaunchArgs, k)
					print("Added arg " .. k)
				end
			else -- launch without
				if k == "--launch" then restartGame = true end -- you are in the launcher and want to restart but dont want to leave
				if lauchArgsString:find(k) then
					restartGame = true
					for i = 1, #lastLaunchArgs do if lastLaunchArgs[i] == k then table.remove(lastLaunchArgs, i) break end end
					print("Removed arg " .. k)
				end
			end
		end

		if not launchVanilla then
			for i, mod in ipairs(self.modList) do
				if mod.enabled ~= self.getModEnabled(mod) then
					mod.enabled = self.getModEnabled(mod)
					restartGame = true
				end
			end
		end
		dpf.saveJson(mods["beatblock-plus-launcher"].path .. "/config.json", mods["beatblock-plus-launcher"].config)

		if restartGame then
			local launchArgs = table.concat(lastLaunchArgs, " ")

			local osName = love.system.getOS()

			if osName == "Windows" then
				self.command = "start beatblock.exe " .. launchArgs
			elseif osName == "OS X" then
				self.command = "open beatblock.app " .. launchArgs .. " &"
			else -- assume Linux
				self.command = "./beatblock " .. launchArgs .. " &"
			end

			love.window.close()
			self.timer = 20
			self.doRelaunch = nil
		else -- nothing much changed, no need to restart
			if bs.states.Menu == nil then dofile('preload/states.lua') end
			cs = bs.load(project.initState)
			cs:init()
		end
	end
	if self.timer then
		self.timer = self.timer - dt
		if self.timer <= 0 then
			self.timer = nil
			os.execute(self.command)
			love.event.quit()
		end
	end
end)

st:setFgDraw(function(self)
	if mods["beatblock-plus-launcher"].config.useBeatblockPlusStyle then bbp.gui.pushStyle() end

	helpers.SetNextWindowPos(0, 0, "ImGuiCond_Always")
	helpers.SetNextWindowSize(1200, 720, "ImGuiCond_Always")
	if imgui.Begin("Launcher", true, bit.bor(imgui.ImGuiWindowFlags_NoMove, imgui.ImGuiWindowFlags_NoResize, imgui.ImGuiWindowFlags_NoTitleBar)) then
		local buttons = {}
		if mods["beatblock-plus-launcher"].config.showVanilla then table.insert(buttons, { "Launch Vanilla", { ["--launch"] = true, ["--disable-mods"] = true } }) end
		if mods["beatblock-plus-launcher"].config.showConsole then table.insert(buttons, { "Launch with console", { ["--launch"] = true } }) end
		if mods["beatblock-plus-launcher"].config.showConsoleless then table.insert(buttons, { "Launch without console", { ["--launch"] = true, ["--disable-console"] = true } }) end
		if mods["beatblock-plus-launcher"].config.showRelaunch then table.insert(buttons, { "Restart Launcher", {} }) end

		local width = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x * (#buttons - 1)) / #buttons
		for i = 1, #buttons do
			if i ~= 1 then imgui.SameLine() end
			local label = buttons[i][1]
			local args = buttons[i][2]
			if imgui.Button(label, imgui.ImVec2_Float(width, 33 * self.size + imgui.GetStyle().ItemSpacing.y)) then self.doRelaunch = args end
		end

		if imgui.BeginTabBar("beatblockPlusLauncherProfiles", imgui.ImGuiTabBarFlags_AutoSelectNewTabs + imgui.ImGuiTabBarFlags_Reorderable) then
			for name, data in pairs(mods["beatblock-plus-launcher"].config.profiles) do
				if name ~= "Create Profile" then
					local notDeleted = ffi.new("bool[1]", { true })
					if imgui.BeginTabItem(name, name ~= "Enable All" and notDeleted or nil, self.initing and mods["beatblock-plus-launcher"].config.currentProfile == name and imgui.ImGuiTabItemFlags_SetSelected or 0) then
						if name ~= "Enable All" then
							local v = ffi.new("char[?]", 2 ^ 16)
							ffi.copy(v, name, #name)
							imgui.SetNextItemWidth(-1e-9)
							imgui.InputText("##profileName", v, 2 ^ 16, imgui.ImGuiInputTextFlags_AutoSelectAll)
							if imgui.IsItemDeactivatedAfterEdit() and name ~= ffi.string(v) and not ({ ["Enable All"] = true, ["New Profile"] = true, ["Create Profile"] = true })[ffi.string(v)] and mods["beatblock-plus-launcher"].config.profiles[ffi.string(v)] == nil then
								mods["beatblock-plus-launcher"].config.profiles[ffi.string(v)] = data
								mods["beatblock-plus-launcher"].config.profiles[name] = nil
								mods["beatblock-plus-launcher"].config.currentProfile = ffi.string(v)
								name = ffi.string(v)
								self:reloadModList()
							end
						end
						if mods["beatblock-plus-launcher"].config.currentProfile ~= name then
							mods["beatblock-plus-launcher"].config.currentProfile = name
							self:reloadModList()
						end
						imgui.EndTabItem(name)
					end
					if name ~= "Enable All" and not notDeleted[0] then
						mods["beatblock-plus-launcher"].config.profiles[name] = nil
						if mods["beatblock-plus-launcher"].config.currentProfile == name then
							mods["beatblock-plus-launcher"].config.currentProfile = "Enable All"
							self:reloadModList()
							self.justDeleted = true
						end
					end
				end
			end
			if imgui.BeginTabItem("Enable All", nil, imgui.ImGuiTabItemFlags_Leading + (self.justDeleted and imgui.ImGuiTabItemFlags_SetSelected or 0)) then imgui.EndTabItem("Enable All") end -- need this to prevent tab deletion and instant recreation
			if mods["beatblock-plus-launcher"].config.profiles["New Profile"] == nil and imgui.BeginTabItem("Create Profile", nil, imgui.ImGuiTabItemFlags_Trailing) then
				if not self.justDeleted then
					mods["beatblock-plus-launcher"].config.profiles["New Profile"] = {}
					for i, mod in ipairs(self.modList) do mods["beatblock-plus-launcher"].config.profiles["New Profile"][mod.id] = true end
				end
				imgui.EndTabItem("Create Profile")
			end
			self.justDeleted = false
		end

		for i, mod in ipairs(self.modList) do
			if not self.getModEnabled(mod) then
				imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Button, imgui.ImVec4_Float(0.25, 0, 0, 1))
				imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ButtonHovered, imgui.ImVec4_Float(0.35, 0, 0, 1))
				imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ButtonActive, imgui.ImVec4_Float(0.5, 0, 0, 1))
			end
			imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Button, imgui.ImVec4_Float(0, 0, 0, 0))
			local pressed = imgui.ImageButton("##imageButton" .. i, mod.icon or sprites.bbp.missing, imgui.ImVec2_Float(73 * self.size, 33 * self.size))
			if mods["beatblock-plus-launcher"].config.currentProfile == "Enable All" then imgui.SetItemTooltip("Profile doesnt allow toggling") end
			imgui.PopStyleColor(1)
			imgui.SameLine()
			local pressed2 = imgui.Button(mod.name .. " (" .. mod.version .. ") by " .. mod.author .. "\n" .. mod.description .. "##".. i, imgui.ImVec2_Float(-1e-9, 33 * self.size + imgui.GetStyle().ItemSpacing.y))
			if mods["beatblock-plus-launcher"].config.currentProfile == "Enable All" then imgui.SetItemTooltip("Profile doesnt allow toggling") end
			if not self.getModEnabled(mod) then imgui.PopStyleColor(3) end

			if mods["beatblock-plus-launcher"].config.currentProfile ~= "Enable All" and (pressed or pressed2) then
				mods["beatblock-plus-launcher"].config.profiles[mods["beatblock-plus-launcher"].config.currentProfile][mod.id] = not self.getModEnabled(mod)
				self:reloadModList()
			end
		end
		imgui.End()
	end
	if mods["beatblock-plus-launcher"].config.useBeatblockPlusStyle then bbp.gui.popStyle() end

	self.initing = nil
end)

return st