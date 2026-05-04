# Windows Onboarding Script

Tá»± Ä‘á»™ng cÃ i Ä‘áº·t toÃ n bá»™ mÃ´i trÆ°á»ng phÃ¡t triá»ƒn cho mÃ¡y Windows 11.

## CÃ¡ch sá»­ dá»¥ng

### CÃ¡ch 1: Cháº¡y trá»±c tiáº¿p tá»« GitHub (Nhanh nháº¥t)

Má»Ÿ **Terminal/PowerShell vá»›i quyá»n Administrator**, sau Ä‘Ã³ dÃ¡n lá»‡nh:

```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/kienbb/onboard-setup/main/install.ps1' -OutFile '$env:TEMP\install.ps1'; & '$env:TEMP\install.ps1'"
```

Script sáº½ tá»± Ä‘á»™ng:
- Táº£i vá» `%TEMP%\install.ps1`
- Cháº¡y vá»›i quyá»n Admin (tá»± relaunch náº¿u cáº§n)
- CÃ i Ä‘áº·t toÃ n bá»™ vÃ  tá»± resume sau restart

### CÃ¡ch 2: Táº£i script vá» mÃ¡y trÆ°á»›c

#### 1. Clone hoáº·c download repository

```bash
git clone https://github.com/kienbb/onboard-setup.git
cd onboard-setup
```

#### 2. Má»Ÿ PowerShell vá»›i quyá»n Administrator

- Nháº¥n `Win + X` â†’ chá»n **Terminal (Admin)** hoáº·c **Windows PowerShell (Admin)**
- Hoáº·c: Nháº¥p chuá»™t pháº£i vÃ o file `install.ps1` â†’ **Run with PowerShell** (script sáº½ tá»± Ä‘á»™ng yÃªu cáº§u Admin náº¿u cáº§n)

#### 3. Cháº¡y script

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Hoáº·c náº¿u Ä‘ang á»Ÿ trong PowerShell Admin:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install.ps1
```

## Quy trÃ¬nh cÃ i Ä‘áº·t

Script cháº¡y qua **12 Phase** tá»± Ä‘á»™ng:

| Phase | Ná»™i dung | TÆ°Æ¡ng tÃ¡c |
|-------|----------|-----------|
| 0 | Bootstrap (Chocolatey, Winget) | KhÃ´ng |
| 1 | WSL2, IIS, Ubuntu, Dark Mode, Git config | KhÃ´ng |
| 2 | Kiá»ƒm tra sau restart | KhÃ´ng |
| 3 | CÃ i pháº§n má»m (Chrome, Discord, VS Code, Node.js, ...) | KhÃ´ng |
| 4 | Python 3.10â€“3.13 qua pyenv-win | KhÃ´ng |
| 5 | Rust | KhÃ´ng |
| 6 | IIS Hosting Bundle (.NET 8, 9) | KhÃ´ng |
| 7 | Visual Studio Community (ASP.NET, C++, Unity) | Hiá»‡n progress UI, **khÃ´ng cáº§n click** |
| 8 | OpenCode Desktop | KhÃ´ng |
| 9 | Claude Code CLI + OpenCode CLI | KhÃ´ng |
| 10 | VS Code Extension (Claude Code) | KhÃ´ng |
| 11 | Dá»n dáº¹p & bÃ¡o cÃ¡o | KhÃ´ng |

## Khá»Ÿi Ä‘á»™ng láº¡i mÃ¡y

Script sáº½ **tá»± Ä‘á»™ng restart mÃ¡y 1 láº§n** sau Phase 1 (khi cÃ i WSL2 + IIS).
- Sau restart, script tá»± Ä‘á»™ng cháº¡y láº¡i vÃ  tiáº¿p tá»¥c tá»« Phase 2.
- **Báº¡n khÃ´ng cáº§n lÃ m gÃ¬ thÃªm.**

## Náº¿u script bá»‹ ngáº¯t giá»¯a chá»«ng

DÃ¹ bá»‹ **máº¥t Ä‘iá»‡n, crash, hoáº·c Ä‘Ã³ng cá»­a sá»•**, báº¡n chá»‰ cáº§n:

```powershell
.\install.ps1
```

Script sáº½ tá»± Ä‘á»™ng:
- Äá»c tráº¡ng thÃ¡i Ä‘Ã£ lÆ°u
- **Bá» qua cÃ¡c pháº§n má»m Ä‘Ã£ cÃ i**
- Tiáº¿p tá»¥c tá»« Ä‘iá»ƒm giÃ¡n Ä‘oáº¡n

## Sau khi script hoÃ n táº¥t

CÃ¡c pháº§n cáº§n xá»­ lÃ½ **thá»§ cÃ´ng**:

1. **Unity**: Má»Ÿ Unity Hub â†’ Ä‘Äƒng nháº­p â†’ cÃ i Unity Editor 6000.4 + modules Android, WebGL, iOS
2. **WSL2/Ubuntu**: Náº¿u láº§n Ä‘áº§u khá»Ÿi Ä‘á»™ng Ubuntu, cáº§n táº¡o username/password
3. **Restart**: Náº¿u cÃ³ thÃ´ng bÃ¡o yÃªu cáº§u restart tá»« báº¥t ká»³ pháº§n má»m nÃ o

## Danh sÃ¡ch pháº§n má»m Ä‘Æ°á»£c cÃ i

### CÃ´ng cá»¥ há»‡ thá»‘ng
- 7-Zip
- Windows Terminal
- PowerToys
- Git (Ä‘Ã£ config sáºµn `kiennt` / `kiennt@pixon.games`)
- WSL2 + Ubuntu

### TrÃ¬nh duyá»‡t & Giao tiáº¿p
- Google Chrome
- Discord
- Telegram Desktop

### Láº­p trÃ¬nh
- VS Code + Claude Code Extension
- Visual Studio Community 2022 (ASP.NET, Desktop C++, Unity workloads)
- Unity Hub
- Fork (Git UI)

### Runtime & NgÃ´n ngá»¯
- Node.js LTS (bao gá»“m npm)
- Python 3.10, 3.11, 3.12, 3.13 (qua pyenv-win, máº·c Ä‘á»‹nh 3.13)
- .NET SDK 8, 9 (10 náº¿u cÃ³ sáºµn)
- Rust

### Server
- IIS + ASP.NET
- IIS Hosting Bundle (.NET 8, 9)

### OpenCode & AI
- OpenCode Desktop
- OpenCode CLI (`opencode-ai`)
- Claude Code CLI (`@anthropic-ai/claude-code`)

## Troubleshooting

### Lá»—i `ExecutionPolicy`
Náº¿u gáº·p lá»—i chÃ­nh sÃ¡ch thá»±c thi:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

### Winget khÃ´ng tÃ¬m tháº¥y
TrÃªn Windows 11, Winget thÆ°á»ng Ä‘Ã£ cÃ³ sáºµn. Náº¿u thiáº¿u, script sáº½ cá»‘ cÃ i qua Chocolatey. Náº¿u váº«n lá»—i, cÃ i [App Installer](https://apps.microsoft.com/detail/9NBLGGH4NNS1) tá»« Microsoft Store.

### Visual Studio cÃ i lÃ¢u
Visual Studio 2022 ráº¥t náº·ng (15â€“30GB tÃ¹y workload). Phase 7 cÃ³ thá»ƒ máº¥t **30â€“90 phÃºt**. Progress window sáº½ hiá»‡n nhÆ°ng **tá»± Ä‘á»™ng cháº¡y**, báº¡n khÃ´ng cáº§n báº¥m gÃ¬.

### Log file
Xem chi tiáº¿t táº¡i: `%TEMP%\onboarding.log`

## TÃ¡c giáº£

Script Ä‘Æ°á»£c táº¡o tá»± Ä‘á»™ng cho `kiennt@pixon.games`.
