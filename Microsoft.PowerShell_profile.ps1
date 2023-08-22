function pr {
    Set-Location -Path "C:\Users\Paul Cruz\Documents\React"
}
function n {
    Set-Location -Path "C:\Users\Paul Cruz\Documents\Node"
}
function l {
    Set-Location -Path "C:\Users\Paul Cruz\Documents\Laravel"
}
function telegram {
    Set-Location -Path "F:\Juegos\Suzumiya Haruhi\asd\Telegram"
}
function p {
    Set-Location -Path "C:\Users\Paul Cruz\Documents\PHP"
}

function tg {
    Start-Process "F:\Juegos\Suzumiya Haruhi\asd\Telegram\Telegram.exe"
}


function vite {
   pnpm create vite@latest $args[0];
   Set-Location $args[0];
   pnpm i;
   code .;
   pnpm run dev;
}


function qw {
    Invoke-Item ./;
}