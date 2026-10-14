param(
    [Parameter(Mandatory = $false)]
    [string]$TaskFile = "prompts\00_baseline_readonly.md"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path ".git")) {
    Write-Host "Git 저장소가 아닙니다. 먼저 프로젝트 루트에서 git init과 첫 커밋을 만들어주세요." -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Host "codex 명령을 찾지 못했습니다. Codex 설치와 로그인을 먼저 완료하세요." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $TaskFile)) {
    Write-Host "작업 파일이 없습니다: $TaskFile" -ForegroundColor Red
    exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$taskName = [IO.Path]::GetFileNameWithoutExtension($TaskFile)
$logDir = Join-Path "logs\codex" "${stamp}_${taskName}"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

$prompt = Get-Content $TaskFile -Raw -Encoding UTF8

Write-Host "실행 작업: $TaskFile" -ForegroundColor Cyan
Write-Host "로그 위치: $logDir" -ForegroundColor Cyan

codex exec `
    --sandbox workspace-write `
    -o (Join-Path $logDir "final.md") `
    $prompt 2>&1 | Tee-Object -FilePath (Join-Path $logDir "console.log")

Write-Host "완료. 변경 사항을 반드시 검토하세요:" -ForegroundColor Green
Write-Host "  git status"
Write-Host "  git diff"
Write-Host "  Get-Content $(Join-Path $logDir 'final.md')"
