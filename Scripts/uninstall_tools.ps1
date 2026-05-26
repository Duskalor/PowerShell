# Uninstall tools installed on 2026-05-26
# Run this if you want to revert to the previous setup.
#
# After running this, also remove the "# --- TOOLS BLOCK ---" section from the profile
# or run: git checkout main -- Microsoft.PowerShell_profile.ps1

$winget = "C:\Users\Paul Cruz\AppData\Local\Microsoft\WindowsApps\winget.exe"

Write-Host "Uninstalling tools..."

& $winget uninstall --id ajeetdsouza.zoxide        --silent
& $winget uninstall --id Starship.Starship          --silent
& $winget uninstall --id sharkdp.bat               --silent
& $winget uninstall --id eza-community.eza          --silent
& $winget uninstall --id BurntSushi.ripgrep.MSVC   --silent
& $winget uninstall --id sharkdp.fd                --silent

Write-Host ""
Write-Host "Done. To fully revert the profile run:"
Write-Host "  git -C `"$PSScriptRoot\.."` checkout HEAD~1 -- Microsoft.PowerShell_profile.ps1"
