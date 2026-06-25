@{
    # PSScriptAnalyzer settings for the PowerShell scripts embedded in Git-Ape
    # skills (.github/skills/**/*.ps1). Enforced by the "Git-Ape: Script Lint"
    # workflow (.github/workflows/git-ape-script-lint.yml).
    #
    # The gate fails on any finding at Error or Warning severity. Two rules are
    # excluded because they are inappropriate for these scripts:
    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Skill scripts are interactive CLI tools whose whole job is to print
        # human-readable status (checkmarks, warnings, progress) to the console.
        # Write-Host is the correct call here, not a design smell.
        'PSAvoidUsingWriteHost'

        # These scripts emit emoji and box-drawing characters and are invoked
        # cross-platform (bash + pwsh). A UTF-8 BOM is undesirable on Linux/macOS
        # and would break the byte-for-byte scaffold parity check in
        # git-ape-onboarding-template-check.yml, so files are kept BOM-less.
        'PSUseBOMForUnicodeEncodedFile'
    )
}
