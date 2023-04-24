-- 99_cleanup
do
	local boot_env = get_boot_env()
	if boot_env then
		boot_env.PRINT_PREFIX = "[CLEANUP] "
	else
		error("Failed to get boot environment. Is the file being run at boot time?")
	end
	print("Deallocating environment variables...")
	if _LOOSE then
		print("LOOSE BIOS found, deallocating...")
		_LOOSE_ERR = nil
		_LOOSE_PRINT = nil
		_LOOSE_WARN = nil
		_LOOSE_WRITE = nil
		print("Done!")
	end
	BOOT_FN = nil
	-- CORE_BOOT_FS = nil
end