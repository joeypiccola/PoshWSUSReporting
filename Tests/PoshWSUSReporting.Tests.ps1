$ModuleManifestName = 'PoshWSUSReporting.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\PoshWSUSReporting\$ModuleManifestName"
Import-Module $ModuleManifestPath -Force

Describe 'Module Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath
        $? | Should Be $true
    }

    It 'Should load' {
        $Module = Get-Module 'PoshWSUSReporting'
        $Module.Name | Should Be 'PoshWSUSReporting'
        $Commands = $Module.ExportedCommands.Keys
        $Commands -contains 'Approve-PoshWSUSRUpdate' | Should Be $True
        $Commands -contains 'Connect-PoshWSUSR' | Should Be $True
        $Commands -contains 'Get-PoshWSUSRComputerUpdates' | Should Be $True
        $Commands -contains 'Get-PoshWSUSRGroup' | Should Be $True
        $Commands -contains 'Get-PoshWSUSRGroupMembers' | Should Be $True
        $Commands -contains 'Get-PoshWSUSRGroupOverview' | Should Be $True
        $Commands -contains 'Get-PoshWSUSRGroupUpdateSummary' | Should Be $True
        $Commands -contains 'Get-PoshWSUSRServerUpdates' | Should Be $True
        $Commands -contains 'Get-PoshWSUSRUpdateDetails' | Should Be $True
    }
}