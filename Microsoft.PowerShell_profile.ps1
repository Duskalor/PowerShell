$user = $env:USERNAME


function w {
    Invoke-Item ./;
}
function pr {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\React"
}
function fr {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\React\frontEndMentor"
}
function n {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\Node"
}
function as {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\astro"
}
function l {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\Laravel"
}
function p {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\PHP"
}
function ne {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\Nextjs"
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
function next {
   pnpx create-next-app@latest $args[0];
   Set-Location $args[0];
   code .;
   pnpm run dev;
}

function vitet {
   pnpm create vite@latest $args[0];
   Set-Location $args[0];
   pnpm install -D tailwindcss postcss autoprefixer;
   npx tailwindcss init -p;
   pnpm i;   
   code .;
   pnpm run dev;
}




function astro {
   pnpm create astro@latest $args[0];
   Set-Location $args[0];
   code .;
   pnpm run dev;
}


