--$ @config bullets=round

[#FF0000 LooseOS Filesystem]

- bin: OS Binaries. Always in PATH.
- lib: OS Libraries. Key for any code to run.
- usr/bin: User Binaries. Always in PATH.
- usr/lib: User Libraries. Usually installed with OPPM or LPM.
- usr/profile.lua: Runs when a shell is opened.
- home: Usually mounted on a secondary, larger drive.
- src: LooseOS source code. Crucial for the operating system to boot.
- install: Files that come from packages that have been installed. Has it's own lib and bin directories.