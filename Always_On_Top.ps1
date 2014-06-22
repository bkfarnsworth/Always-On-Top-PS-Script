#Requires -Version 2.0 

$signature = @"
	
	[DllImport("user32.dll")]  
	public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);  

	public static IntPtr FindWindow(string windowName){
		return FindWindow(null,windowName);
	}

	[DllImport("user32.dll")]
	public static extern bool SetWindowPos(IntPtr hWnd, 
	IntPtr hWndInsertAfter, int X,int Y, int cx, int cy, uint uFlags);

	[DllImport("user32.dll")]  
	public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); 

	static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
	static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);

	const UInt32 SWP_NOSIZE = 0x0001;
	const UInt32 SWP_NOMOVE = 0x0002;

	const UInt32 TOPMOST_FLAGS = SWP_NOMOVE | SWP_NOSIZE;

	public static void MakeTopMost (IntPtr fHandle)
	{
		SetWindowPos(fHandle, HWND_TOPMOST, 0, 0, 0, 0, TOPMOST_FLAGS);
	}

	public static void MakeNormal (IntPtr fHandle)
	{
		SetWindowPos(fHandle, HWND_NOTOPMOST, 0, 0, 0, 0, TOPMOST_FLAGS);
	}
"@


$app = Add-Type -MemberDefinition $signature -Name Win32Window -Namespace ScriptFanatic.WinAPI -ReferencedAssemblies System.Windows.Forms -Using System.Windows.Forms -PassThru

function Set-TopMost
{
	param(		
		[Parameter(
			Position=0,ValueFromPipelineByPropertyName=$true
		)][Alias('MainWindowHandle')]$hWnd=0,

		[Parameter()][switch]$Disable
	)
	
	if($hWnd -ne 0)
	{
		if($Disable)
		{
			Write-Verbose "Set process handle :$hWnd to NORMAL state"
			$null = $app::MakeNormal($hWnd)
			return
		}
		
		Write-Verbose "Set process handle :$hWnd to TOPMOST state"
		$null = $app::MakeTopMost($hWnd)
	}
	else
	{
		Write-Verbose "$hWnd is 0"
	}
}

function getOpenApplications(){

    $openApplications = Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select-Object MainWindowTitle 

    #This block was for getting a windows explorer window, which supposedlly didn't get caught in the above line, but it is...
    #$a = New-Object -com "Shell.Application"
    #$b = $a.windows() | select-object LocationName
    #$c = "Windows Explorer: " + $b.LocationName
    #$openApplications += $c

    return $openApplications
}

function Get-WindowByTitle($WindowTitle="*")
{
	Write-Verbose "WindowTitle is: $WindowTitle"
	
	if($WindowTitle -eq "*")
	{
		Write-Verbose "WindowTitle is *, print all windows title"
		Get-Process | Where-Object {$_.MainWindowTitle} | Select-Object Id,Name,MainWindowHandle,MainWindowTitle
	}
	else
	{
		Write-Verbose "WindowTitle is $WindowTitle"
		Get-Process | Where-Object {$_.MainWindowTitle -like "*$WindowTitle*"} | Select-Object Id,Name,MainWindowHandle,MainWindowTitle
	}
}


function forceApplicationOnTop($chosenApplication){

    #Exaples:

    # set powershell console on top of other windows 
    #gps powershell | Set-TopMost 

    # unset
    #gps powershell | Set-TopMost -disable


    # set an application on top of other windows by its windows title (wildcard is supported)
    #Get-WindowByTitle *pad* | Set-TopMost 

    # unset
    #Get-WindowByTitle textpad | Set-TopMost -Disable

    Write-Host "Chosen Window: "$chosenApplication

    $openApplications = getOpenApplications
    
    $openApplications | ForEach-Object {
        Get-WindowByTitle $_.MainWindowTitle | Set-TopMost -Disable
    }

    Get-WindowByTitle $chosenApplication | Set-TopMost 

}

function createDropdownBox($openApplications){

    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 

    $objForm = New-Object System.Windows.Forms.Form 
    $objForm.Text = "Always On Top"
    $objForm.Size = New-Object System.Drawing.Size(300,200) 
    $objForm.StartPosition = "CenterScreen"

    $objForm.KeyPreview = $True
    $objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
        {$x=$objListBox.SelectedItem;$objForm.Close()}})
    $objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
        {$objForm.Close()}})

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Size(75,120)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()})
    $objForm.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Size(150,120)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.Add_Click({$objForm.Close()})
    $objForm.Controls.Add($CancelButton)

    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(10,20) 
    $objLabel.Size = New-Object System.Drawing.Size(280,20) 
    $objLabel.Text = "Select a window to keep on top:"
    $objForm.Controls.Add($objLabel) 

    $objListBox = New-Object System.Windows.Forms.ListBox 
    $objListBox.Location = New-Object System.Drawing.Size(10,40) 
    $objListBox.Size = New-Object System.Drawing.Size(260,20) 
    $objListBox.Height = 80

    $openApplications | ForEach-Object {
        [void] $objListBox.Items.Add( $_.MainWindowTitle)
    }

    $objForm.Controls.Add($objListBox) 

    $objForm.Topmost = $True

    $objForm.Add_Shown({$objForm.Activate()})
    [void] $objForm.ShowDialog()

    $x=$objListBox.SelectedItem;

    return $x

}


############ Script starts here ###################

$openApplications = getOpenApplications
$chosenApplication = createDropdownBox($openApplications)
forceApplicationOnTop($chosenApplication)



