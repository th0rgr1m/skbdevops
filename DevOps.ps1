#
# When I wrote it, only God and I knew how it works. Now God alone knows.
# It's just a joke. You should hire me. It will be useful for all of us. I'm serious.
# It was the best task for last month.
#


param
    (
        [Parameter(Mandatory=$true)]# Define directory with all items
        [string] $TargetDirectory,
        
        [Parameter(Mandatory=$true)]# Define URL of repository
        [string] $GitLabRepo,

        [Parameter(Mandatory=$true)]# Define number of script iterations
        [string] $NumberofIterations,

        [Parameter(Mandatory=$true)]# Define time between iterations in seconds
        [string] $SecondsToSleep
       
    )

#For this test you should use gitlab repository: "https://gitlab.com/kontur-tasks/trytobuild.git"

# Create $TargetDirectory if it doesn't exist
if(!(Test-Path -Path $TargetDirectory))
{
    New-Item -ItemType Directory -Path $TargetDirectory
}

# Create alias for Git if it doesn't exist
$GitAlias = Get-Alias -Name git
if ($GitAlias.count -lt 1)
{
    New-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe"
}

# Create alias for MSbuild if it doesn't exist
$GitAlias = Get-Alias -Name msbuild
if ($GitAlias.count -lt 1)
{
    New-Alias -Name msbuild -Value "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\Bin\MSbuild.exe"
}

# Create alias for Nuget if it doesn't exist
$GitAlias = Get-Alias -Name nuget
if ($GitAlias.count -lt 1)
{
    New-Alias -Name nuget -Value "$Env:ProgramFiles\Nuget\nuget.exe"
}


# First receiving of project files


# Clone project sources to target directory
cd $TargetDirectory
git clone $GitLabRepo

# Get project directory
$ProjectDirectory = $TargetDirectory | Get-ChildItem -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
cd $ProjectDirectory.FullName

# Obtain last commit hash for Nuget description
$CommitHash = git rev-parse --short HEAD

# Obtain last commit author for Nuget description
$CommitAuthor = git log -1 --pretty=format:'%an'

cd $TargetDirectory

# Get sources for creating application
$AppSource = Get-ChildItem -Path $TargetDirectory -Recurse | ?{$_.Name -like "*.csproj"}

# Create application
msbuild $AppSource.FullName

# Start application and save data to file
$App = Get-ChildItem -Path $TargetDirectory -Recurse | ?{$_.Name -like "*.exe"}
Invoke-Expression $App[0].FullName | Out-File -FilePath ($TargetDirectory+"\"+"outfile.txt")

# Obtain description for Nuget package
$AppContent = Get-Content -Path ($TargetDirectory+"\"+"outfile.txt")

# Get project file and cut his name
$ProjectFile = Get-ChildItem -Path $TargetDirectory -Recurse | ?{$_.Name -like "*.csproj"}
$ProjectName = $ProjectFile.Name.TrimEnd(".csproj")

# Create Nuget spec
nuget spec $ProjectName

# Get projects's info from AssemblyInfo.cs
$AssemblyInfoFile = Get-ChildItem -Path $TargetDirectory -Recurse | ?{$_.Name -like "*AssemblyInfo.cs"}
$AssemblyInfo = Get-Content $AssemblyInfoFile.FullName

# Obtain product ID
$Product = ($AssemblyInfo -match 'AssemblyProduct\(".*"\)')
$Product = $Product -split ('"')
$Product = $Product[1]

# Obtain version number
$Version = ($AssemblyInfo -match 'AssemblyFileVersion\(".*"\)')
$Version = $Version -split ('"')
$Version = $Version[1]

# Get Nuget spec
$NugetFile = Get-ChildItem -Path $TargetDirectory -Recurse | ?{$_.Name -like "*.nuspec"}

# Convert object to string
$NugetXML = [string]$NugetFile.FullName

# Edit Nuget XML
$Xml = New-Object XML
$Xml.Load($NugetXML)

# Edit Nuget XML (Product ID)
$NugetXMLid =  $Xml.SelectSingleNode("//id")
$NugetXMLid.InnerText = $Product+".skb.dev.dvs" # I'm using the custom name because "The package ID 'Test' is not available" on Nuget.org

# Edit Nuget XML (Product Version)
$NugetXMLversion =  $Xml.SelectSingleNode("//version")
$NugetXMLversion.InnerText = $Version

# Edit Nuget XML (Product description from test task)
$NugetXMLdescription =  $Xml.SelectSingleNode("//description")
$NugetXMLdescription.InnerText = $AppContent+"_"+"Hash:"+$CommitHash

# Edit Nuget XML (Product description from test task)
$NugetXMLauthors =  $Xml.SelectSingleNode("//authors")
$NugetXMLauthors.InnerText = $CommitAuthor

# Edit Nuget XML (Myself as owner)
$NugetXMLowners =  $Xml.SelectSingleNode("//owners")
$NugetXMLowners.InnerText = "Dmitry Simbirtsev"

# Edit Nuget XML (Tags is a sample value and should be removed)
$NugetXMLowners =  $Xml.SelectSingleNode("//tags")
$NugetXMLowners.InnerText = $null

# Edit Nuget XML (ReleaseNotes is a sample value and should be removed)
$NugetXMLowners =  $Xml.SelectSingleNode("//releaseNotes")
$NugetXMLowners.InnerText = $null

# Save Nuget XML after edit
$Xml.Save($NugetXML)

# Create Nuget package
nuget pack $NugetFile.Name

# Publish Nuget package
$NugetServer = "https://www.nuget.org"
$ApiKey = "oy2azmk5ta7r7ex4vbwa6koefixuqtrehgxjnuwrrtcfa4"
$Package = Get-ChildItem | ? {$_.Extension -eq ".nupkg"}
nuget push -Source $NugetServer $Package $ApiKey

# First sllep after first itearation
Start-Sleep $SecondsToSleep


# Script cycle with user-defined $NumberofIterations


$i=0
for ($i; $i -lt $NumberofIterations; $i++)
{
    cd $ProjectDirectory.FullName

    # Searching the difference between local origin and GitLab master
    $CheckNewCommit = (git diff origin/master)

    # If the difference was found - create a new project folder 
    if ($CheckNewCommit -ne $null)
    {
            $NewTargetDirectory = ($TargetDirectory+"_new_"+(Get-Date -Format "dd.MM.yyyy.HH.mm.ss"))
            
            New-Item -ItemType Directory -Path $NewTargetDirectory
            
            cd $NewTargetDirectory
            git clone $GitLabRepo

            $NewProjectDirectory = $NewTargetDirectory | Get-ChildItem -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            cd $NewProjectDirectory.FullName

            $CommitHash = git rev-parse --short HEAD

            $CommitAuthor = git log -1 --pretty=format:'%an'

            cd $NewTargetDirectory

            $AppSource = Get-ChildItem -Path $NewTargetDirectory -Recurse | ?{$_.Name -like "*.csproj"}

            msbuild $AppSource.FullName

            $App = Get-ChildItem -Path $NewTargetDirectory -Recurse | ?{$_.Name -like "*.exe"}
            Invoke-Expression $App[0].FullName | Out-File -FilePath ($NewTargetDirectory+"\"+"outfile.txt")

            $AppContent = Get-Content -Path ($NewTargetDirectory+"\"+"outfile.txt")

            $ProjectFile = Get-ChildItem -Path $NewTargetDirectory -Recurse | ?{$_.Name -like "*.csproj"}
            $ProjectName = $ProjectFile.Name.TrimEnd(".csproj")

            nuget spec $ProjectName

            $AssemblyInfoFile = Get-ChildItem -Path $NewTargetDirectory -Recurse | ?{$_.Name -like "*AssemblyInfo.cs"}
            $AssemblyInfo = Get-Content $AssemblyInfoFile.FullName

            $Product = ($AssemblyInfo -match 'AssemblyProduct\(".*"\)')
            $Product = $Product -split ('"')
            $Product = $Product[1]

            $Version = ($AssemblyInfo -match 'AssemblyFileVersion\(".*"\)')
            $Version = $Version -split ('"')
            $Version = $Version[1]

            $NugetFile = Get-ChildItem -Path $NewTargetDirectory -Recurse | ?{$_.Name -like "*.nuspec"}

            $NugetXML = [string]$NugetFile.FullName

            $Xml = New-Object XML
            $Xml.Load($NugetXML)

            $NugetXMLid =  $Xml.SelectSingleNode("//id")
            $NugetXMLid.InnerText = $Product+".skb.dev.dvs"

            $NugetXMLversion =  $Xml.SelectSingleNode("//version")
            $NugetXMLversion.InnerText = $Version

            $NugetXMLdescription =  $Xml.SelectSingleNode("//description")
            $NugetXMLdescription.InnerText = $AppContent+"_"+"Hash:"+$CommitHash

            $NugetXMLauthors =  $Xml.SelectSingleNode("//authors")
            $NugetXMLauthors.InnerText = $CommitAuthor

            $NugetXMLowners =  $Xml.SelectSingleNode("//owners")
            $NugetXMLowners.InnerText = "Dmitry Simbirtsev"

            $NugetXMLowners =  $Xml.SelectSingleNode("//tags")
            $NugetXMLowners.InnerText = $null

            $NugetXMLowners =  $Xml.SelectSingleNode("//releaseNotes")
            $NugetXMLowners.InnerText = $null

            $Xml.Save($NugetXML)

            nuget pack $NugetFile.Name

            $NugetServer = "https://www.nuget.org"
            $ApiKey = "oy2azmk5ta7r7ex4vbwa6koefixuqtrehgxjnuwrrtcfa4"
            $Package = Get-ChildItem | ? {$_.Extension -eq ".nupkg"}
            nuget push -Source $NugetServer $Package $ApiKey

            # Define new latest project files location 
            $ProjectDirectory = $NewProjectDirectory

            Start-Sleep $SecondsToSleep
    }
    else
    {
        # If the difference wasn't found - start-sleep until the new iteration
        Start-Sleep $SecondsToSleep
    }
}
