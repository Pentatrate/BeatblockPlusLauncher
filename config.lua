mod.config.showVanilla = helpers.InputBool("Launch Vanilla button", mod.config.showVanilla)
mod.config.showConsole = helpers.InputBool("Launch with console button", mod.config.showConsole)
mod.config.showConsoleless = helpers.InputBool("Launch without console button", mod.config.showConsoleless)
mod.config.showRelaunch = helpers.InputBool("Relaunch Launcher button", mod.config.showRelaunch)

imgui.Separator()

mod.config.useBeatblockPlusStyle = helpers.InputBool("Use BBP style in launcher", mod.config.useBeatblockPlusStyle or false)

imgui.Separator()

if bs.states.Launcher and imgui.Button("Open Launcher") then
	cs = bs.load("Launcher")
	cs:init()
end