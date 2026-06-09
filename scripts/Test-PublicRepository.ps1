param(
    [Parameter(Position = 0)]
    [string] $Root = '.'
)

$ErrorActionPreference = 'Stop'
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$violations = [Collections.Generic.List[string]]::new()

$blockedExtensions = [Collections.Generic.HashSet[string]]::new(
    [string[]] @(
        '.7z', '.age', '.bak', '.db', '.der', '.env', '.gz', '.key', '.p12',
        '.pem', '.pfx', '.sqlite', '.sqlite3', '.tar', '.zip'
    ),
    [StringComparer]::OrdinalIgnoreCase
)

$contentRules = [ordered] @{
    'private key material' = '-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----'
    'age encrypted payload' = 'age-encryption\.org/v1'
    'GitHub token' = '\bgh[pousr]_[A-Za-z0-9_]{20,}\b'
    'AWS access key' = '\bAKIA[0-9A-Z]{16}\b'
    'private IPv4 address' = '\b(?:10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(?:1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})\b'
    'Windows user profile path' = '(?i)\b[A-Z]:\\Users\\[^\\\r\n]+'
    'Linux user profile path' = '(?i)(?<![A-Za-z0-9_])/home/[A-Za-z0-9._-]+'
}

$files = @(
    Get-ChildItem -LiteralPath $rootPath -Recurse -File -Force |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
)

foreach ($item in Get-ChildItem -LiteralPath $rootPath -Recurse -Force) {
    if ($item.FullName -match '[\\/]\.git(?:[\\/]|$)') {
        continue
    }
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $violations.Add("reparse point is not allowed: $($item.FullName)")
    }
}

foreach ($file in $files) {
    $relativePath = [IO.Path]::GetRelativePath($rootPath, $file.FullName).Replace('\', '/')
    $extension = [IO.Path]::GetExtension($file.Name)

    if ($blockedExtensions.Contains($extension)) {
        $violations.Add("blocked file type '$extension': $relativePath")
        continue
    }
    if ($file.Length -gt 1MB) {
        $violations.Add("file exceeds 1 MiB: $relativePath")
        continue
    }

    $content = Get-Content -Raw -LiteralPath $file.FullName
    foreach ($rule in $contentRules.GetEnumerator()) {
        if ($content -match $rule.Value) {
            $violations.Add("$($rule.Key): $relativePath")
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | Sort-Object -Unique | ForEach-Object {
        Write-Error $_ -ErrorAction Continue
    }
    throw "Public repository validation failed with $($violations.Count) finding(s)."
}

Write-Output "Public repository validation passed: $($files.Count) file(s)"
