#!/usr/bin/env pwsh
New-Item -Path $PSScriptRoot/.git/hooks -Name pre-push -ItemType HardLink -Value $PSScriptRoot/hooks/pre-push -Force
New-Item -Path $PSScriptRoot/.git/hooks -Name pre-commit -ItemType HardLink -Value $PSScriptRoot/hooks/pre-commit -Force
New-Item -Path $PSScriptRoot/.git/hooks -Name post-merge -ItemType HardLink -Value $PSScriptRoot/hooks/post-merge -Force
