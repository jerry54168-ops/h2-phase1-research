# STATIC CANDIDATE. Future invocation: pwsh -NoLogo -NoProfile -NonInteractive -File ...
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ExpectedBindingsPath,
      [Parameter(Mandatory)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$expected = Get-Content -LiteralPath $ExpectedBindingsPath -Raw | ConvertFrom-Json
# Defense in depth only; separate Human admission must HOLD before any workflow run.
if ($expected.execution_authorization -cne 'YES' -or
    $expected.PINNING_STANDARD -cnotin @('EXACT_HOST','USER_SPACE_EQUIVALENT') -or
    $expected.cost_policy -cne 'NO_PAID_USAGE' -or
    $expected.repository_policy -cne 'FUTURE_RESEARCH_ONLY_REPOSITORY' -or
    $expected.self_hosted_allowed -ne $false -or $expected.larger_runner_allowed -ne $false -or
    $expected.paid_addon_allowed -ne $false -or $expected.runtime_attempt_budget -ne 1) {
    throw 'HOLD: unresolved or unauthorized execution/pinning/cost boundary'
}
foreach ($name in @('account','repository','runner_label','runner_class','runner_image_identity',
    'powershell_tool_identity','dotnet_tool_identity','tool_supply_plan','pinning_acceptance_contract',
    'freshness_evidence_contract','workflow_revision_sha256','artifact_retention_days',
    'checkout_action_revision','upload_action_revision','download_action_revision','credential_boundary')) {
    $value = [string]$expected.$name
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match 'UNKNOWN|UNDECIDED|NOT_PROVIDED|UNRESOLVED') {
        throw "HOLD: unresolved binding $name"
    }
}
if ($env:GITHUB_RUN_ATTEMPT -cne '1' -or $env:GITHUB_REPOSITORY -cne $expected.repository) {
    throw 'HOLD: attempt or repository identity mismatch'
}
# All runtime observations originate in this process, not in a dotnet subprocess.
$observed = [ordered]@{
    process_id = $PID
    psedition = $PSVersionTable.PSEdition
    powershell_version = $PSVersionTable.PSVersion.ToString()
    framework_description = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
    runtime_version = [System.Environment]::Version.ToString()
    os_description = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    os_architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    process_architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
    runner_os = $env:RUNNER_OS
    runner_arch = $env:RUNNER_ARCH
    runner_name = $env:RUNNER_NAME
    image_os = $env:ImageOS
    image_version = $env:ImageVersion
}
$provider = [ordered]@{
    run_id = $env:GITHUB_RUN_ID
    run_attempt = $env:GITHUB_RUN_ATTEMPT
    job_id = $env:GITHUB_JOB
    workflow_ref = $env:GITHUB_WORKFLOW_REF
    workflow_sha = $env:GITHUB_WORKFLOW_SHA
    repository = $env:GITHUB_REPOSITORY
    commit_sha = $env:GITHUB_SHA
    logical_context = $env:PHASE1_CONTEXT
    check_run_id = 'UNAVAILABLE_REQUIRES_SEPARATELY_BOUND_PROVIDER_EVIDENCE'
    observed_at_utc = [DateTime]::UtcNow.ToString('o')
}
$runtimeMatches = ($observed.psedition -ceq 'Core' -and
    $observed.powershell_version -match '^7\.4\.\d+(?:$|[-+])' -and
    $observed.framework_description -match '^\.NET 8\.0\.\d+(?:$|[-+])' -and
    $observed.runtime_version -match '^8\.0\.\d+(?:$|[-+])')
$roleMatches = (($provider.job_id -ceq 'builder' -and $env:PHASE1_CONTEXT -ceq 'Builder-context') -or
    ($provider.job_id -ceq 'reviewer' -and $env:PHASE1_CONTEXT -ceq 'Reviewer-context') -or
    ($provider.job_id -ceq 'validator' -and $env:PHASE1_CONTEXT -ceq 'Validator-context'))
$idsPresent = ($provider.run_id -match '^\d+$' -and $provider.run_attempt -ceq '1' -and
    $roleMatches -and -not [string]::IsNullOrWhiteSpace($provider.workflow_sha))
$receipt = [ordered]@{
    receipt_kind = 'SAME_PROCESS_RUNTIME'
    result = 'HOLD_PENDING_PINNING_FRESHNESS_AND_PROVIDER_EVIDENCE_REVIEW'
    logical_context = $env:PHASE1_CONTEXT
    observed = $observed
    expected = $expected
    provider = $provider
    runtime_predicate = $runtimeMatches
    provider_context_predicate = $idsPresent
    same_process_evidence = $true
    independent_reviewer_governance = 'NOT_CLOSED_BY_PHASE1'
}
[IO.File]::WriteAllText($OutputPath, ($receipt | ConvertTo-Json -Depth 12) + "`n", [Text.UTF8Encoding]::new($false))
if (-not $runtimeMatches -or -not $idsPresent) { throw 'HOLD: same-process or provider identity mismatch' }
# Observations cannot constitute final pinning/freshness acceptance or full Phase 1 PASS.
