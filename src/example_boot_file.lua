--nn_filename

--This code is available under the GNU GPLv3 license. <https://www.gnu.org/licenses/gpl-3.0.en.html>

do
	local boot_env = get_boot_env()
	if boot_env then
		boot_env.PRINT_PREFIX = "[NAME] "
	else
		error("Failed to get boot environment. Is the file being run at boot time?")
	end

	--Your code here
end