$user = $env:USERNAME


function w {
    Invoke-Item ./;
}
function pr {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\React"
}
function n {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\Node"
}
function l {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\Laravel"
}
function p {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\PHP"
}
function power {
    Set-Location -Path "C:\Users\$user\Documents\PowerShell\";
    code .;
}

function tg {
    Start-Process "F:\Juegos\Suzumiya Haruhi\asd\Telegram\Telegram.exe"
}
function telegram {
    Set-Location -Path "F:\Juegos\Suzumiya Haruhi\asd\Telegram"
}

function vite {
   pnpm create vite@latest $args[0];
   Set-Location $args[0];
   pnpm i;
   code .;
   pnpm run dev;
}


