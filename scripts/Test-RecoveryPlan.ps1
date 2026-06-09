param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Path
)

$ErrorActionPreference = 'Stop'

$planPath = (Resolve-Path -LiteralPath $Path).Path
$plan = Get-Content -Raw -LiteralPath $planPath | ConvertFrom-Json

if ($plan.schemaVersion -ne 1) {
    throw "Unsupported recovery-plan schema version: $($plan.schemaVersion)"
}

$services = @($plan.services)
if ($services.Count -eq 0) {
    throw 'Recovery plan must contain at least one service.'
}

$byName = @{}
foreach ($service in $services) {
    $name = [string] $service.name
    if ($name -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        throw "Invalid service name '$name'. Use lowercase kebab-case."
    }
    if ($byName.ContainsKey($name)) {
        throw "Duplicate service name: $name"
    }
    if ([string]::IsNullOrWhiteSpace([string] $service.description)) {
        throw "Service '$name' is missing a description."
    }
    if (@($service.checks).Count -eq 0) {
        throw "Service '$name' must define at least one recovery check."
    }
    $byName[$name] = $service
}

$incoming = @{}
$dependents = @{}
foreach ($name in $byName.Keys) {
    $incoming[$name] = 0
    $dependents[$name] = [Collections.Generic.List[string]]::new()
}

foreach ($service in $services) {
    $name = [string] $service.name
    $seenDependencies = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($dependency in @($service.dependsOn)) {
        $dependencyName = [string] $dependency
        if (-not $byName.ContainsKey($dependencyName)) {
            throw "Service '$name' depends on unknown service '$dependencyName'."
        }
        if ($dependencyName -eq $name) {
            throw "Service '$name' cannot depend on itself."
        }
        if (-not $seenDependencies.Add($dependencyName)) {
            throw "Service '$name' repeats dependency '$dependencyName'."
        }
        $incoming[$name]++
        $dependents[$dependencyName].Add($name)
    }
}

$ready = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
foreach ($name in $incoming.Keys) {
    if ($incoming[$name] -eq 0) {
        [void] $ready.Add($name)
    }
}

$order = [Collections.Generic.List[string]]::new()
while ($ready.Count -gt 0) {
    $name = $ready.Min
    [void] $ready.Remove($name)
    $order.Add($name)

    foreach ($dependent in $dependents[$name]) {
        $incoming[$dependent]--
        if ($incoming[$dependent] -eq 0) {
            [void] $ready.Add($dependent)
        }
    }
}

if ($order.Count -ne $services.Count) {
    $cyclic = @($incoming.Keys | Where-Object { $incoming[$_] -gt 0 } | Sort-Object)
    throw "Recovery plan contains a dependency cycle involving: $($cyclic -join ', ')"
}

Write-Output "Recovery plan valid: $($services.Count) service(s)"
for ($index = 0; $index -lt $order.Count; $index++) {
    Write-Output ('{0,2}. {1}' -f ($index + 1), $order[$index])
}
