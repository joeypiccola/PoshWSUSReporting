$ModuleManifestName = 'PoshWSUSReporting.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\PoshWSUSReporting\$ModuleManifestName"
Import-Module $ModuleManifestPath -Force

Describe 'Module Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath
        $? | Should Be $true
    }

    $Module = Get-Module 'PoshWSUSReporting'
    $Module.Name | Should Be 'PoshWSUSReporting'
    $Commands = $Module.ExportedCommands.Keys
    foreach ($command in $commands) {
        it "Should load $command" {
            $commands -contains $command | should Be $true
        }
    }
}