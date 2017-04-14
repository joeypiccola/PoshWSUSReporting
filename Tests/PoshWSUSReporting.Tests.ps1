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
    }  
}