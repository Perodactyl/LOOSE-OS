--04_term

--This code is available under the GNU GPLv3 license. <https://www.gnu.org/licenses/gpl-3.0.en.html>

do
	local boot_env = get_boot_env()
	if boot_env then
		boot_env.PRINT_PREFIX = "[TERM] "
	else
		error("Failed to get boot environment. Is the file being run at boot time?")
	end

	print("Declaring term...")
	local term = {}
	


	print("Globalizing term...")
	_G.term = term
end